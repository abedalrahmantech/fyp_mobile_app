-- =============================================================================
-- Gap #4: Historical-performance-aware driver recommendation
-- Creates a lat/lng overload used by the admin portal which includes
-- completion rate, average delivery minutes, and an adjusted score.
-- =============================================================================

create or replace function public.recommend_driver_for_tasks(
  p_company_id uuid,
  p_task_lat double precision,
  p_task_lng double precision
)
returns table (
  member_id uuid,
  email text,
  is_available boolean,
  task_count integer,
  distance_km double precision,
  completion_rate double precision,
  avg_delivery_minutes double precision,
  recommendation_score double precision
)
language sql
stable
security definer
as $$
  with driver_distances as (
    select
      cm.id                      as member_id,
      cm.email,
      cm.is_available,
      cm.current_task_count      as task_count,
      case
        when cm.last_known_location is not null then
          ST_Distance(
            cm.last_known_location,
            ST_SetSRID(ST_MakePoint(p_task_lng, p_task_lat), 4326)::geography
          ) / 1000.0
        else 9999.0
      end                        as distance_km
    from public.company_members cm
    where cm.company_id = p_company_id
      and cm.role = 'driver'
  ),
  perf as (
    select
      t.driver_id,
      count(*)::double precision                              as total,
      count(*) filter (where t.status = 'delivered')::double precision as delivered,
      avg(
        extract(epoch from (t.updated_at - t.created_at)) / 60.0
      ) filter (where t.status = 'delivered')                 as avg_minutes
    from public.tasks t
    where t.company_id = p_company_id
      and t.driver_id is not null
    group by t.driver_id
  )
  select
    dd.member_id,
    dd.email,
    dd.is_available,
    dd.task_count,
    round(dd.distance_km::numeric, 2)::double precision,
    coalesce(round((p.delivered / nullif(p.total, 0))::numeric, 3), 0)::double precision
      as completion_rate,
    coalesce(round(p.avg_minutes::numeric, 1), 0)::double precision
      as avg_delivery_minutes,
    -- Composite score =
    --   availability weight  × proximity factor × workload factor × performance factor
    (case when dd.is_available then 1.0 else 0.5 end)
    * (1.0 / (1.0 + dd.distance_km))
    * (1.0 / (1.0 + dd.task_count))
    * (0.5 + 0.5 * coalesce(p.delivered / nullif(p.total, 0), 0))
      as recommendation_score
  from driver_distances dd
  left join perf p on p.driver_id = dd.member_id
  where public.is_company_member(p_company_id)
  order by recommendation_score desc;
$$;
