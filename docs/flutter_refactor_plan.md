# Flutter Client Refactor Plan

Goal: Evolve the current single-screen demo into the IR1 driver mobile MVP with auth, offline-first behavior, telemetry, and LLM access while keeping the codebase maintainable.

## Layered Architecture
1. **Core Configuration**
   - `AppConfig` reads `--dart-define` envs (Supabase, Mapbox, OpenAI, telemetry endpoint, release channel).
   - Singleton exposed via provider for easy overrides in tests.

2. **Services Layer**
   - `SupabaseClientProvider`: initializes authenticated clients and handles token refresh.
   - `MapboxService`: wraps Optimization and Directions APIs with fallbacks and caching.
   - `TelemetryService`: streams location + sensor payloads to ingestion endpoint, queues offline.
   - `LLMService`: talks to Edge Function for grounded copilot responses.

3. **Repositories**
   - `TaskRepository`: orchestrates Supabase queries, local cache, sync queue, and optimistic updates.
   - `RouteRepository`: fetches persisted routes/ETAs, triggers re-optimization requests.
   - `MediaRepository`: manages barcode scans, photo capture, presigned upload lifecycle.

4. **Local Persistence & Sync Engine**
   - Use Drift for offline storage of tasks, routes, queue entries, media drafts, and telemetry breadcrumbs (shared schema with repository layer).
   - Sync engine handles:
     - enqueue→flush pattern with retry/backoff.
     - conflict detection (server timestamp vs local change id).
     - state hydration on cold start.

5. **State Management**
   - Replace ad-hoc ChangeNotifiers with feature-specific view models extending a common base that supports:
     - loading/error instrumentation
     - connection state awareness
     - dependency injection for repositories/services.
   - Consider `riverpod` if complexity grows; otherwise keep `provider` with new base classes.

6. **Presentation**
   - Screens: Auth, Shift Selector, Task List, Task Detail, Map/Route view, Proof-of-Delivery capture, Copilot chat.
   - Shared components for status chips, offline banners, sync indicators, and error surfaces.

## Implementation Stages
1. **Config + Dependency Injection**
   - Add `AppBootstrap` that initializes config, logging, and service locators before running `runApp`.

2. **Auth & Session Flow**
   - Introduce onboarding/login (email OTP or magic link via Supabase) and driver profile store.
   - Persist session tokens securely (flutter_secure_storage) and renew silently.

3. **Offline Cache + Repositories**
   - Scaffold Drift database with tables: `tasks`, `routes`, `route_tasks`, `task_events`, `sync_queue`.
   - Implement repository APIs consumed by view models.

4. **UI Restructure**
   - Convert current `TaskListScreen` to consume repository data streams and show offline state.
   - Add Task Detail & PoD capture surfaces.

5. **Telemetry + Map Integration**
   - Hook background geolocation (geolocator + workmanager), feed telemetry service, visualize on map.

6. **Copilot Interface**
   - Chat sheet component invoking LLM service with contextual grounding (task IDs, ETAs).

7. **Testing & Instrumentation**
   - Widget tests for critical flows, mock repositories for offline scenarios, integration test for sync queue.
   - Add logging hooks (e.g., `logger` package) honoring `ORDERVISTA_LOG_LEVEL`.

This staged plan keeps each pull request focused while marching toward the IR1 deliverables.
