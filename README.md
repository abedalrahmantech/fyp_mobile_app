# OrderVista Dispatch Demo

OrderVista Dispatch is a lightweight Flutter client that showcases the driver-side
workflow for a logistics and delivery optimization platform. The app is designed
to help shipping professionals track assigned loads, confirm deliveries, and
stay in sync with dispatch operations during early product demos.

## Feature Overview
- Delivery task list with task ID, destination, and live status.
- Pull-to-refresh sync powered by Supabase (tasks filtered to the configured driver).
- Delivery confirmation workflow that updates Supabase rows and emits local cache changes.
- Optional proof-of-delivery code capture for barcode or QR simulations.
- Offline/demo fallback data so the UI remains usable when the network is unavailable.

## Architecture at a Glance
- **State management:** `ChangeNotifier` view model exposed via `provider`.
- **Networking:** `TaskService` now uses `supabase_flutter` for realtime-friendly RPCs instead of HTTP stubs.
- **UI:** Material widgets with a dispatcher-focused theme.
- **Demo support:** Sample data ships with the app for presentations without backend access.

## Running the App
1. Ensure Flutter (stable channel) is installed and `flutter doctor` passes.
2. Copy `.env.example` to `.env`, fill in the Supabase / Mapbox / OpenAI keys (plus the driver/company IDs), then launch with `flutter run --dart-define-from-file=.env` (or configure VS Code run settings accordingly).
4. Fetch dependencies and launch:
	```bash
	flutter pub get
	flutter run
	```

## Local Persistence & Code Generation
The driver client persists tasks/routes offline using [Drift](https://drift.simonbinder.eu/). Whenever you update `lib/data/ordervista_database.dart`, regenerate the companions/data classes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

During development you can keep the generator running with `dart run build_runner watch`.

## Environment Variables
The project reads secrets and runtime configuration from an env file that is **not** committed to git. Use the following convention:

1. Duplicate `.env.example` → `.env`.
2. Provide values for:
	- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, optional `SUPABASE_SERVICE_ROLE_KEY`
	- `ORDERVISTA_COMPANY_ID`, `ORDERVISTA_DRIVER_ID` (demo IDs live in `.env.example`)
	- `MAPBOX_ACCESS_TOKEN`, `OPENAI_API_KEY`
	- `ORDERVISTA_API_BASE_URL`, `ORDERVISTA_TELEMETRY_ENDPOINT`, `ORDERVISTA_DISPATCH_PORTAL_URL`
3. Start the Flutter app with `--dart-define-from-file=.env` so the variables are injected at build time (CI workflows will do the same).

The real `.env` file stays local; only `.env.example` should be committed.

## Backend Contract
- `tasks` table (Supabase / Postgres) remains the canonical source. Mobile queries filter by `company_id` and `driver_id`.
- Task completion updates the row (`status = delivered`, optional `proof_code`) and trusts Supabase RLS for authorization.

## Next Steps
- Add authentication and driver shift management.
- Integrate live routing, ETA, and capacity insights.
- Capture geolocation and proof-of-delivery photos.
- Harden error handling and telemetry for production readiness.
