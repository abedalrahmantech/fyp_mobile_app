# OrderVista Backend Contracts (IR1)

## Supabase Schema Overview
All tables include `id uuid primary key`, `company_id uuid`, `created_at timestamptz default now()`, `updated_at timestamptz default now()`. Row Level Security (RLS) enforces `auth.uid()` membership in `company_members` for the specified role.

### Core Tables
- **companies**: org metadata.
- **company_members**: links `auth.users` to `company_id`, stores `role` (`driver`, `dispatcher`, `admin`).
- **vehicles**: `driver_id`, `plate`, `capacity_kg`, `active_route_id`.
- **tasks**:
  - `external_ref`, `address`, `lat`, `lng`, `status`, `scheduled_start`, `scheduled_end`, `priority`, `proof_code`, `proof_photo_url`.
  - RLS: drivers can `select`/`update` only tasks assigned to their active route; dispatchers can manage company tasks.
- **routes**:
  - `vehicle_id`, `driver_id`, `status`, `start_time`, `end_time`, `optimizer` (`mapbox`, `fallback`), `eta_summary jsonb`.
- **route_tasks** (ordered stops):
  - `route_id`, `task_id`, `sequence`, `planned_arrival`, `planned_departure`, `travel_distance_m`, `travel_duration_s`.
- **telemetry_events**:
  - `driver_id`, `vehicle_id`, `task_id?`, `location geography(Point,4326)`, `speed_kph`, `heading`, `battery`, `sequence_id`, `source` (`device`, `simulator`).
- **sync_queue_items**:
  - Tracks pending actions from mobile clients (type, payload, status, retries) for observability.
- **media_artifacts**:
  - `task_id`, `driver_id`, `type` (`photo`, `barcode`, `signature`), `storage_path`, `expires_at`, `checksum`.

### Support Tables
- **geofence_rules**: polygon or radial definitions with trigger conditions.
- **notifications**: log of dispatcher-driver messages.
- **audit_log**: Edge Functions append structured events for compliance.

## Row-Level Security Policies
1. **Company isolation**: `company_id = auth.jwt() ->> 'company_id'`.
2. **Driver task access**: allow `select/update` on `tasks` where `id` is part of driver’s active route in `routes` + `route_assignments` view.
3. **Telemetry insert**: drivers can insert only for their own `driver_id`; dispatchers/admins can read aggregated views.
4. **Media access**: signed URLs generated via Edge Function; direct table access limited to owner roles.

## Edge Functions
1. `optimize-route`:
   - **Input**: `{ routeId?, vehicleId, driverId, stops: [{ taskId, lat, lng, serviceMinutes }] }
   - **Flow**: fetch API keys from env → call Mapbox Optimization API → persist `routes` + `route_tasks` rows (within transaction) → emit realtime event.
   - **Output**: `{ routeId, status: "optimized", etaSummary }`.

2. `chat-interaction`:
   - **Input**: `{ driverId, prompt }`.
   - **Flow**: gather context (active tasks, delays, alerts) → construct grounded prompt → call OpenAI → return response + citations.
   - **Output**: `{ reply, citations: [{ type: "task", id: "..." }] }`.

3. `telemetry-ingest`:
   - **Input**: batch `{ events: [{ timestamp, lat, lng, speed, heading, taskId? }] }`.
   - **Flow**: validate signature, insert into `telemetry_events`, evaluate geofence rules, emit suggestions.
   - **Output**: `{ accepted, rejected, geofenceHits: [...] }`.

4. `proof-upload`:
   - **Input**: `{ taskId, mediaType, checksum }`.
   - **Flow**: generate presigned storage URL scoped to company/task, log artifact row, return upload URL.
   - **Output**: `{ uploadUrl, artifactId }`.

5. `csv-import` (dispatcher portal):
   - **Input**: file upload reference.
   - **Flow**: parse CSV, geocode addresses (Mapbox Geocoding), create tasks, return summary.

Each function validates JWT, enforces role-specific limits, and writes to `audit_log` with correlation IDs.

## External Interfaces
- **Realtime Channels**: `company:{id}:tasks`, `company:{id}:routes`, `driver:{id}:telemetry-suggestions`.
- **Storage Buckets**: `proofs/{company_id}/{task_id}/...` with limited TTL signed URLs.

## Migration Strategy
- Version SQL in `/supabase/migrations` with clear forward/backward steps.
- Seed scripts create demo company, driver, dispatcher for development/testing.
- Use Supabase CLI to manage Edge Function deploys.

This contract aligns mobile, dispatcher web, and backend services around the IR1 scope and will be expanded as features mature.
