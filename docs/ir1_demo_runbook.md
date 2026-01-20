# IR1 Demo Runbook

## Preconditions
- Supabase schema applied (routes, route_tasks, telemetry_events, media_artifacts).
- .env configured (Supabase + Mapbox + driver/company IDs).

## Phase 1: Baseline route sequencer
1. Open /admin.
2. Create 2+ pending tasks with valid HK addresses.
3. Click “Generate baseline route”.
4. Expected: “Route created: … with N stops.”

## Phase 2: Route overview + assignment
1. Scroll to “Routes & Stop Order”.
2. Confirm route shows ordered stops.
3. Click “Assign driver” and enter a driver UUID.
4. Expected: Route status becomes assigned; tasks updated to driver.

## Phase 3: Telemetry + geofence stub (driver app)
1. Open task list.
2. Enter lat/lng and select a task.
3. Click “Check proximity”.
4. Expected: Message indicating distance or arrival suggestion.
5. Click “Send telemetry”.
6. Expected: Telemetry row inserted in Supabase.

## Phase 4: Proof-of-delivery metadata
1. Open a task.
2. Click “Proof of Delivery”.
3. Enter proof code + photo URL/path.
4. Expected: Task updated and media_artifacts row created.

## Phase 5: Observability
- Check browser console for log lines prefixed with timestamps and event names:
  - tasks.fetch.start / tasks.fetch.success
  - tasks.complete.*
  - tasks.pod.*

## Build/Run (web)
- flutter run -d web-server --dart-define-from-file=.env
