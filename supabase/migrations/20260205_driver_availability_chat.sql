-- Migration: Add driver availability tracking and chat messaging
-- Date: 2026-02-05

-- =============================================================================
-- Driver Availability Columns
-- =============================================================================
-- Add availability status and location to company_members for driver management
alter table public.company_members 
  add column if not exists is_available boolean not null default false,
  add column if not exists last_known_location geography(point, 4326),
  add column if not exists last_location_at timestamptz,
  add column if not exists current_task_count integer not null default 0;

-- Index for querying available drivers
create index if not exists idx_company_members_availability 
  on public.company_members(company_id, role, is_available) 
  where role = 'driver';

-- Index for location-based queries
create index if not exists idx_company_members_location 
  on public.company_members using gist (last_known_location);

-- =============================================================================
-- Chat Messages Table for Admin-Driver Communication
-- =============================================================================
create table if not exists public.chat_messages (
  id uuid primary key default uuid_generate_v4(),
  company_id uuid not null references public.companies(id) on delete cascade,
  sender_id uuid not null references public.company_members(id) on delete cascade,
  recipient_id uuid references public.company_members(id) on delete set null,
  is_broadcast boolean not null default false,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

-- Indexes for chat queries
create index if not exists idx_chat_messages_company on public.chat_messages(company_id, created_at desc);
create index if not exists idx_chat_messages_recipient on public.chat_messages(recipient_id, read_at) where recipient_id is not null;
create index if not exists idx_chat_messages_sender on public.chat_messages(sender_id, created_at desc);

-- Enable RLS on chat_messages
alter table public.chat_messages enable row level security;

-- Chat message policies
create policy "company members read chat messages" on public.chat_messages
  for select using (
    public.is_company_member(company_id)
    and (
      sender_id in (select id from public.company_members where user_id = auth.uid())
      or recipient_id in (select id from public.company_members where user_id = auth.uid())
      or is_broadcast = true
    )
  );

create policy "company members send chat messages" on public.chat_messages
  for insert with check (
    public.is_company_member(company_id)
    and sender_id in (select id from public.company_members where user_id = auth.uid())
  );

create policy "recipients mark messages read" on public.chat_messages
  for update using (
    public.is_company_member(company_id)
    and recipient_id in (select id from public.company_members where user_id = auth.uid())
  );

-- =============================================================================
-- Helper function to update driver location and availability
-- =============================================================================
create or replace function public.update_driver_status(
  p_is_available boolean default null,
  p_lat double precision default null,
  p_lng double precision default null
)
returns void
language plpgsql
security definer
as $$
declare
  v_member_id uuid;
begin
  -- Get the member id for the current user
  select id into v_member_id
  from public.company_members
  where user_id = auth.uid()
  limit 1;

  if v_member_id is null then
    raise exception 'User is not a company member';
  end if;

  -- Update availability if provided
  if p_is_available is not null then
    update public.company_members
    set is_available = p_is_available
    where id = v_member_id;
  end if;

  -- Update location if provided
  if p_lat is not null and p_lng is not null then
    update public.company_members
    set 
      last_known_location = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      last_location_at = now()
    where id = v_member_id;
  end if;
end;
$$;

-- =============================================================================
-- Helper function to get drivers with availability and location info
-- =============================================================================
create or replace function public.get_available_drivers(p_company_id uuid)
returns table (
  member_id uuid,
  user_id uuid,
  role text,
  is_available boolean,
  current_task_count integer,
  last_location_lat double precision,
  last_location_lng double precision,
  last_location_at timestamptz
)
language sql
stable
security definer
as $$
  select 
    cm.id as member_id,
    cm.user_id,
    cm.role,
    cm.is_available,
    cm.current_task_count,
    ST_Y(cm.last_known_location::geometry) as last_location_lat,
    ST_X(cm.last_known_location::geometry) as last_location_lng,
    cm.last_location_at
  from public.company_members cm
  where cm.company_id = p_company_id
    and cm.role = 'driver'
    and public.is_company_member(p_company_id);
$$;

-- =============================================================================
-- Function to calculate distance between driver and task cluster
-- =============================================================================
create or replace function public.recommend_driver_for_tasks(
  p_company_id uuid,
  p_task_ids uuid[]
)
returns table (
  member_id uuid,
  is_available boolean,
  current_task_count integer,
  distance_to_cluster_m double precision,
  recommendation_score double precision
)
language sql
stable
security definer
as $$
  with task_centroid as (
    -- Calculate the centroid of all task locations
    select ST_Centroid(ST_Collect(location::geometry))::geography as centroid
    from public.tasks
    where id = any(p_task_ids)
      and location is not null
  ),
  driver_distances as (
    select 
      cm.id as member_id,
      cm.is_available,
      cm.current_task_count,
      case 
        when cm.last_known_location is not null and tc.centroid is not null
        then ST_Distance(cm.last_known_location, tc.centroid)
        else 999999999
      end as distance_to_cluster_m
    from public.company_members cm
    cross join task_centroid tc
    where cm.company_id = p_company_id
      and cm.role = 'driver'
  )
  select 
    dd.member_id,
    dd.is_available,
    dd.current_task_count,
    dd.distance_to_cluster_m,
    -- Score: prioritize available drivers, then by distance and task count
    case 
      when dd.is_available then 1.0 else 0.5 
    end 
    * (1.0 / (1.0 + dd.distance_to_cluster_m / 1000.0))
    * (1.0 / (1.0 + dd.current_task_count))
    as recommendation_score
  from driver_distances dd
  where public.is_company_member(p_company_id)
  order by recommendation_score desc;
$$;

-- =============================================================================
-- Trigger to update task count when tasks are assigned/completed
-- =============================================================================
create or replace function public.update_driver_task_count()
returns trigger
language plpgsql
as $$
begin
  -- Update old driver's count if driver changed
  if TG_OP = 'UPDATE' and old.driver_id is distinct from new.driver_id then
    if old.driver_id is not null then
      update public.company_members
      set current_task_count = greatest(0, current_task_count - 1)
      where id = old.driver_id;
    end if;
  end if;

  -- Update new driver's count
  if TG_OP = 'INSERT' or (TG_OP = 'UPDATE' and old.driver_id is distinct from new.driver_id) then
    if new.driver_id is not null and new.status != 'delivered' then
      update public.company_members
      set current_task_count = current_task_count + 1
      where id = new.driver_id;
    end if;
  end if;

  -- Decrement count when task is delivered
  if TG_OP = 'UPDATE' and old.status != 'delivered' and new.status = 'delivered' then
    if new.driver_id is not null then
      update public.company_members
      set current_task_count = greatest(0, current_task_count - 1)
      where id = new.driver_id;
    end if;
  end if;

  return new;
end;
$$;

-- Create trigger for task count updates
drop trigger if exists tasks_update_driver_count on public.tasks;
create trigger tasks_update_driver_count
  after insert or update on public.tasks
  for each row
  execute function public.update_driver_task_count();

-- =============================================================================
-- Add updated_at trigger for chat_messages
-- =============================================================================
select public.install_touch_triggers('public.chat_messages');

-- =============================================================================
-- RPC function to resolve company member by email (if not exists)
-- =============================================================================
create or replace function public.resolve_company_member_by_email(
  email text,
  company_id uuid
)
returns uuid
language sql
stable
security definer
as $$
  select cm.id
  from public.company_members cm
  join auth.users u on u.id = cm.user_id
  where u.email = resolve_company_member_by_email.email
    and cm.company_id = resolve_company_member_by_email.company_id
  limit 1;
$$;

-- =============================================================================
-- Customer Tracking Feature
-- =============================================================================
-- Add tracking_code column to tasks for customer-facing lookups
alter table public.tasks 
  add column if not exists tracking_code text unique;

-- Index for tracking code lookups
create index if not exists idx_tasks_tracking_code 
  on public.tasks(tracking_code) 
  where tracking_code is not null;

-- Function to generate tracking codes (auto-generated on task creation)
create or replace function public.generate_tracking_code()
returns trigger
language plpgsql
as $$
begin
  -- Generate a unique tracking code: OV-XXXX-XXXX (where X is alphanumeric)
  if new.tracking_code is null then
    new.tracking_code := 'OV-' || 
      upper(substring(md5(random()::text || new.id::text) from 1 for 4)) || '-' ||
      upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 4));
  end if;
  return new;
end;
$$;

-- Trigger to auto-generate tracking codes
drop trigger if exists trg_generate_tracking_code on public.tasks;
create trigger trg_generate_tracking_code
  before insert on public.tasks
  for each row
  execute function public.generate_tracking_code();

-- Update existing tasks to have tracking codes
update public.tasks 
set tracking_code = 'OV-' || 
  upper(substring(md5(random()::text || id::text) from 1 for 4)) || '-' ||
  upper(substring(md5(random()::text || id::text || now()::text) from 1 for 4))
where tracking_code is null;

-- Public RPC for customer tracking lookup (no auth required)
create or replace function public.lookup_delivery_by_tracking(
  p_tracking_code text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_result jsonb;
begin
  select jsonb_build_object(
    'found', true,
    'tracking_code', t.tracking_code,
    'status', t.status,
    'address', 
      case 
        when t.status = 'delivered' then t.address
        else regexp_replace(t.address, '^\d+\s*', '', 'g')  -- Hide exact house number for privacy
      end,
    'scheduled_start', t.scheduled_start,
    'scheduled_end', t.scheduled_end,
    'last_update', t.updated_at,
    'driver_assigned', (t.driver_id is not null),
    'proof_available', (t.proof_code is not null or t.proof_photo_url is not null)
  )
  into v_result
  from public.tasks t
  where upper(t.tracking_code) = upper(p_tracking_code)
  limit 1;

  if v_result is null then
    return jsonb_build_object('found', false, 'message', 'Delivery not found');
  end if;

  return v_result;
end;
$$;

-- Grant execute permission to anonymous users for tracking lookups
grant execute on function public.lookup_delivery_by_tracking(text) to anon;
grant execute on function public.lookup_delivery_by_tracking(text) to authenticated;
