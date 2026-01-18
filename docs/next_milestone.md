# Next Milestone Plan (Sprint 2)

Objective: move from demo client to IR1-ready pilot by implementing secure auth, resilient offline sync, and telemetry/geofencing hooks.

## 1. Authentication & Session Foundation
- Implement Supabase email OTP / magic-link login flow in Flutter (UI, state machine, secure token storage).
- Introduce a shift selector screen pulling active routes for the authenticated driver.
- Gate all data repositories behind the authenticated session; refresh tokens silently.
- Update widget tests to cover login and ensure logout clears local cache.

## 2. Offline Queue & Sync Engine
- Expand Drift schema with `task_events`, `media_drafts`, and `sync_queue` tables mirroring Supabase schema.
- Build a dedicated `SyncCoordinator` that:
  - enqueues local mutations (status updates, PoD uploads, telemetry) when offline,
  - retries with exponential backoff,
  - reconciles conflicts using server timestamps.
- Surface sync status in UI (banner + per-task indicators) and add structured logging hooks.

## 3. Telemetry, Geofencing, and Map Context
- Integrate background location collection (geolocator + workmanager) with privacy prompts.
- Stream telemetry to the configured ingestion endpoint, falling back to local buffering.
- Display driver location + route polyline on a Mapbox map widget, highlighting next stop.
- Implement geofence suggestion UI ("You’ve arrived" prompts) driven by local calculations while server validation matures.

## 4. Supabase Edge Integration
- Replace the temporary REST `TaskService` with Supabase queries (authenticated client, RLS compliant).
- Stub `optimize-route`, `chat-interaction`, and `proof-upload` Edge Function clients; add DTOs/tests.
- Wire real-time channel subscriptions for task/route updates.

## 5. Tooling & QA
- Extend CI to run `dart run build_runner build`, Flutter analyze/test, and Supabase lint (SQL format check).
- Add integration tests for offline queue replay and login/logout flows using the in-memory database.

Deliverables: working login + shift experience, persistent offline cache with sync queue, initial telemetry stream, Supabase-backed task fetching, and updated documentation (runbooks + troubleshooting).
