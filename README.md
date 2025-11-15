# OrderVista Dispatch Demo

OrderVista Dispatch is a lightweight Flutter client that showcases the driver-side
workflow for a logistics and delivery optimization platform. The app is designed
to help shipping professionals track assigned loads, confirm deliveries, and
stay in sync with dispatch operations during early product demos.

## Feature Overview
- Delivery task list with task ID, destination, and live status.
- Pull-to-refresh sync that integrates with a REST backend (`GET /tasks`).
- Delivery confirmation workflow that posts updates back to the API (`POST /tasks/complete`).
- Optional proof-of-delivery code capture for barcode or QR simulations.
- Offline/demo fallback data so the UI remains usable when the API is unavailable.

## Architecture at a Glance
- **State management:** `ChangeNotifier` view model exposed via `provider`.
- **Networking:** `TaskService` wraps the `http` client for REST integration.
- **UI:** Material widgets with a dispatcher-focused theme.
- **Demo support:** Sample data ships with the app for presentations without backend access.

## Running the App
1. Ensure Flutter (stable channel) is installed and `flutter doctor` passes.
2. Update `TaskService`'s `baseUrl` if your API is not running on `http://localhost:3000`.
3. Fetch dependencies and launch:
	```bash
	flutter pub get
	flutter run
	```

## Backend Contract
- `GET /tasks` → returns an array of task objects `{ id, address, status, scheduledAt? }`.
- `POST /tasks/complete` → accepts `{ taskId, proofCode? }` and responds with `200` on success.

## Next Steps
- Add authentication and driver shift management.
- Integrate live routing, ETA, and capacity insights.
- Capture geolocation and proof-of-delivery photos.
- Harden error handling and telemetry for production readiness.
