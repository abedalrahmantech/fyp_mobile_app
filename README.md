<div align="center">

# OrderVista: AI-Enhanced Logistics Dispatch Platform

**CS4514 — Final Year Project (2025–2026)**

**City University of Hong Kong**\
Department of Computer Science

| | |
|---|---|
| **Student** | Abed Al Rahman |
| **Supervisor** | Prof. HANCKE, Gerhard Petrus |
| **Project Code** | 25CS022 |

</div>

---

## Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Key Features](#2-key-features)
- [3. System Architecture](#3-system-architecture)
  - [3.1 Technology Stack](#31-technology-stack)
  - [3.2 Layered Architecture](#32-layered-architecture)
  - [3.3 Project Structure](#33-project-structure)
- [4. Database Schema](#4-database-schema)
  - [4.1 Core Tables](#41-core-tables)
  - [4.2 Row-Level Security (RLS)](#42-row-level-security-rls)
  - [4.3 Stored Functions](#43-stored-functions)
  - [4.4 PostGIS & Spatial Indexing](#44-postgis--spatial-indexing)
- [5. Core Algorithms](#5-core-algorithms)
  - [5.1 Nearest-Neighbour Route Optimisation](#51-nearest-neighbour-route-optimisation)
  - [5.2 Haversine Distance Formula](#52-haversine-distance-formula)
  - [5.3 Dynamic Priority Recalculation](#53-dynamic-priority-recalculation)
  - [5.4 Performance-Aware Driver Recommendation](#54-performance-aware-driver-recommendation)
  - [5.5 Offline Sync with Exponential Backoff](#55-offline-sync-with-exponential-backoff)
- [6. AI Integration (Agentic AI)](#6-ai-integration-agentic-ai)
  - [6.1 Agentic Suggestions](#61-agentic-suggestions)
  - [6.2 AI Fleet Summary](#62-ai-fleet-summary)
  - [6.3 Multi-Turn Chat](#63-multi-turn-chat)
- [7. Driver App — User Guide](#7-driver-app--user-guide)
  - [7.1 Authentication](#71-authentication)
  - [7.2 Task List](#72-task-list)
  - [7.3 Proof of Delivery (PoD)](#73-proof-of-delivery-pod)
  - [7.4 GPS Route Re-sequencing](#74-gps-route-re-sequencing)
  - [7.5 AI Suggestions Panel](#75-ai-suggestions-panel)
  - [7.6 Admin Messages](#76-admin-messages)
  - [7.7 Offline Mode](#77-offline-mode)
- [8. Admin Portal — User Guide](#8-admin-portal--user-guide)
  - [8.1 Dashboard](#81-dashboard)
  - [8.2 Task Management](#82-task-management)
  - [8.3 Route Management](#83-route-management)
  - [8.4 Fleet & Driver Management](#84-fleet--driver-management)
  - [8.5 CSV Bulk Import](#85-csv-bulk-import)
  - [8.6 Proof-of-Delivery Records](#86-proof-of-delivery-records)
  - [8.7 Admin Chat & Broadcast Messaging](#87-admin-chat--broadcast-messaging)
  - [8.8 Customer Tracking Lookup](#88-customer-tracking-lookup)
  - [8.9 Agentic Fleet Optimisation](#89-agentic-fleet-optimisation)
- [9. Getting Started](#9-getting-started)
  - [9.1 Prerequisites](#91-prerequisites)
  - [9.2 Environment Configuration](#92-environment-configuration)
  - [9.3 Build & Run](#93-build--run)
  - [9.4 Code Generation (Drift ORM)](#94-code-generation-drift-orm)
  - [9.5 Supabase Setup](#95-supabase-setup)
- [10. Testing](#10-testing)
- [11. Deployment](#11-deployment)
- [12. License](#12-license)

---

## 1. Project Overview

**OrderVista** is a cross-platform AI-enhanced logistics dispatch platform built to address last-mile delivery challenges in Hong Kong. It provides a unified system for dispatchers and drivers to manage delivery tasks, optimise routes, capture proof of delivery, and leverage AI-driven insights — all within a single application.

The platform consists of two main interfaces:

| Interface | Role | Access Route |
|-----------|------|--------------|
| **Driver App** | Field delivery personnel | `/` (default) |
| **Admin Portal** | Dispatchers & fleet managers | `/admin` |

**Core Problem Solved:** Fragmented logistics tools, lack of AI assistance, no unified dispatch-to-driver platform, and poor offline support for mobile drivers in the field.

---

## 2. Key Features

### Driver App (Mobile-First)
| # | Feature | Description |
|---|---------|-------------|
| 1 | Authenticated driver login | Email/password via Supabase Auth with role validation |
| 2 | Real-time task list | Pull-to-refresh with live Supabase sync |
| 3 | Dynamic priority sorting | Time-urgency bonuses (OVERDUE, IMMINENT, APPROACHING, UPCOMING) |
| 4 | Proof of Delivery | Barcode/QR scanning + photo capture |
| 5 | GPS route re-sequencing | Mid-shift nearest-neighbour reorder from current location |
| 6 | Agentic AI suggestions | Proactive one-tap actions (start task, mark delivered, sync, etc.) |
| 7 | Multi-turn AI chat | Conversational delivery assistant |
| 8 | Admin message inbox | Broadcast + direct messages from dispatch |
| 9 | Driver availability toggle | Online/offline status via RPC |
| 10 | Offline-first sync queue | Exponential backoff retry with local Drift cache |
| 11 | Map previews | Mapbox static maps for next destination |
| 12 | Sync status indicators | Pending queue count, last sync time, offline banner |

### Admin Portal (Dispatcher Dashboard)
| # | Feature | Description |
|---|---------|-------------|
| 13 | Fleet dashboard | Summary cards (pending, in-transit, delivered, drivers online) |
| 14 | AI fleet summary | Natural language overview of all active deliveries |
| 15 | Task CRUD | Create, edit, delete, schedule, and assign tasks |
| 16 | Performance-aware driver recommendation | Composite scoring: availability × proximity × workload × history |
| 17 | Route management | Route creation, sequencing, Mapbox optimisation, static map previews |
| 18 | CSV bulk import | Batch task creation with automatic address geocoding |
| 19 | Driver management | Create/deactivate drivers, view performance metrics |
| 20 | Agentic fleet assignment | Multi-driver global nearest-neighbour optimisation |
| 21 | Broadcast & direct messaging | Real-time chat with individual drivers or all at once |
| 22 | Customer tracking lookup | External reference code search for customer-facing status |
| 23 | Proof-of-delivery records | View/download captured PoD artifacts (photos, barcodes) |
| 24 | Multi-tenant isolation | Company-scoped RLS at database level |

---

## 3. System Architecture

### 3.1 Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter 3.x (Dart) | Cross-platform UI (Android, iOS, Web) |
| **State Management** | Provider + ChangeNotifier | Reactive view models |
| **Navigation** | GoRouter | Declarative routing (`/`, `/admin`) |
| **Backend** | Supabase (PostgreSQL + PostGIS) | Auth, database, realtime, RLS, storage |
| **Local Persistence** | Drift 2.18 (SQLite) | Offline cache with stream-based reactivity |
| **Mapping** | Mapbox Geocoding + Static Maps API | Address resolution, map imagery |
| **AI** | OpenRouter / DeepSeek / OpenAI | Agentic suggestions, chat, summaries |
| **PoD Capture** | mobile_scanner + image_picker | Barcode scanning, photo upload |
| **Geolocation** | Geolocator 11.0 | GPS positioning for route optimisation |

### 3.2 Layered Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Presentation Layer                 │
│   DriverAuthGate ← TaskListScreen ← AdminPortal     │
│   (GoRouter, Material 3, Light/Dark Theme)           │
├─────────────────────────────────────────────────────┤
│                  State Management                    │
│   TaskViewModel (ChangeNotifier + Provider)          │
│   Stream<List<DeliveryTask>> from Drift watch()      │
├─────────────────────────────────────────────────────┤
│                   Repository Layer                   │
│   TaskRepository (remote-first, offline fallback)    │
│   Sync queue with exponential backoff replay         │
├─────────────────────────────────────────────────────┤
│                    Service Layer                     │
│   TaskService (Supabase RPC)                         │
│   AiService (OpenRouter/DeepSeek/OpenAI)             │
│   MapboxService (Geocoding + Static Maps + NN)       │
│   DriverProfileService (Auth + Role)                 │
│   AppLogger (Structured observability)               │
├─────────────────────────────────────────────────────┤
│                 Data / Persistence                   │
│   OrderVistaDatabase (Drift ORM)                     │
│   DriftTasks, DriftRoutes, DriftRouteTasks,          │
│   DriftSyncQueue (SQLite native / IndexedDB web)     │
├─────────────────────────────────────────────────────┤
│                   Configuration                      │
│   AppConfig (from --dart-define-from-file=.env)      │
│   AppBootstrap (DI + Supabase init)                  │
├─────────────────────────────────────────────────────┤
│                     Backend                          │
│   Supabase PostgreSQL + PostGIS + RLS                │
│   12+ tables, 15+ RLS policies, stored functions     │
│   Edge Functions (optimize-route, chat, telemetry,   │
│                   proof-upload, csv-import)           │
└─────────────────────────────────────────────────────┘
```

### 3.3 Project Structure

```
lib/
├── main.dart                  # App entry point, GoRouter, MultiProvider
├── index.dart                 # Page barrel exports
├── app/                       # App-level widgets
├── bootstrap/
│   └── app_bootstrap.dart     # Dependency injection & Supabase init
├── config/
│   └── app_config.dart        # Environment configuration singleton
├── data/
│   ├── ordervista_database.dart     # Drift schema (4 tables, migrations)
│   └── connection/
│       ├── native_connection.dart   # SQLite (Android/iOS/Desktop)
│       └── web_connection.dart      # IndexedDB (Web)
├── models/
│   ├── delivery_task.dart     # Core task model with JSON serialisation
│   ├── driver_profile.dart    # Driver identity & role
│   └── ai_action.dart         # Agentic AI action enum + model
├── services/
│   ├── task_service.dart      # Supabase task CRUD operations
│   ├── ai_service.dart        # LLM integration (summary, chat, agentic)
│   ├── mapbox_service.dart    # Geocoding, static maps, NN algorithm
│   ├── driver_profile_service.dart  # Auth profile resolution
│   └── app_logger.dart        # Structured event logging
├── repositories/
│   └── task_repository.dart   # Offline-first cache orchestrator + sync queue
├── viewmodels/
│   └── task_view_model.dart   # Reactive state (sorting, priority, resequencing)
├── screens/
│   ├── auth/
│   │   ├── driver_auth_gate.dart    # Session guard + role validation
│   │   └── driver_login_screen.dart # Email/password login
│   ├── task_list/
│   │   ├── task_list_screen.dart    # Main driver interface
│   │   └── barcode_scanner_sheet.dart # QR/barcode PoD capture
│   └── admin/
│       └── admin_portal_screen.dart # Full dispatcher dashboard
├── components/                # Shared UI components
├── pages/                     # Legacy FlutterFlow pages
├── signin/                    # Legacy sign-in flow
├── start/                     # Splash/onboarding screen
└── flutter_flow/              # FlutterFlow theme utilities

supabase/
└── migrations/
    ├── 20251208_initial_schema.sql              # 12 tables, RLS, indexes
    ├── 20260205_driver_availability_chat.sql     # Chat, driver status RPCs
    └── 20260210_driver_perf_recommendation.sql   # Performance-aware scoring
```

---

## 4. Database Schema

### 4.1 Core Tables

The Supabase PostgreSQL database contains **12+ tables**, all scoped by `company_id` for multi-tenant isolation.

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `companies` | Tenant root | `id`, `name`, `timezone` |
| `company_members` | Users & roles | `user_id`, `company_id`, `role` (driver/dispatcher/admin), `is_available`, `last_known_location`, `current_task_count` |
| `vehicles` | Vehicle registry | `company_id`, `driver_id`, `label`, `plate`, `capacity_kg` |
| `tasks` | Delivery tasks | `company_id`, `address`, `location` (geography), `status`, `priority`, `scheduled_start`, `scheduled_end`, `proof_code`, `proof_photo_url`, `driver_id`, `external_ref` |
| `routes` | Route objects | `company_id`, `vehicle_id`, `driver_id`, `status`, `optimizer` |
| `route_tasks` | Sequence mapping | `route_id`, `task_id`, `sequence`, `travel_distance_m`, `travel_duration_s` |
| `telemetry_events` | GPS tracking | `company_id`, `driver_id`, `location` (geography), `speed_kph`, `heading`, `battery`, `recorded_at` |
| `sync_queue_items` | Offline replay | `company_id`, `driver_id`, `action_type`, `payload` (JSONB), `status`, `attempts`, `last_attempt_at` |
| `media_artifacts` | Photos & docs | `company_id`, `task_id`, `driver_id`, `type`, `storage_path`, `checksum`, `expires_at` |
| `geofence_rules` | Geo-boundaries | `company_id`, `name`, `geometry`, `radius`, `center`, `trigger` |
| `chat_messages` | Messaging | `company_id`, `sender_id`, `recipient_id`, `is_broadcast`, `message`, `read_at` |
| `notifications` | System alerts | `company_id`, `sender_id`, `recipient_id`, `message`, `delivered_at` |
| `audit_log` | Action logging | `actor_id`, `action`, `description`, `metadata` (JSONB) |

### 4.2 Row-Level Security (RLS)

Every table has RLS enabled, enforcing company-level isolation through the helper function `is_company_member(target_company_id)`:

```sql
CREATE FUNCTION is_company_member(target_company_id UUID)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM company_members cm
    WHERE cm.company_id = target_company_id
      AND cm.user_id = auth.uid()
  )
$$ LANGUAGE sql SECURITY DEFINER;
```

**Key Policies:**

| Policy | Table | Rule |
|--------|-------|------|
| Company isolation (SELECT) | All tables | User must be a member of the same company |
| Dispatcher task management | `tasks` | Only dispatcher/admin roles can INSERT/UPDATE |
| Driver self-update | `tasks` | Drivers can UPDATE only their own assigned tasks |
| Driver telemetry insert | `telemetry_events` | `driver_id` must match `auth.uid()` |
| Chat read access | `chat_messages` | User is sender, recipient, or message is broadcast |
| Chat send | `chat_messages` | Sender must be a company member |
| Chat mark read | `chat_messages` | Only the recipient can UPDATE `read_at` |

### 4.3 Stored Functions

| Function | Parameters | Purpose |
|----------|-----------|---------|
| `update_driver_status()` | `p_is_available`, `p_lat`, `p_lng` | Toggle availability + update GPS location (PostGIS point) |
| `get_available_drivers()` | `p_company_id` | List all company drivers with status and location |
| `recommend_driver_for_tasks()` | `p_company_id`, `p_task_lat`, `p_task_lng` | Composite scoring: availability × proximity × workload × performance |
| `resolve_company_member_by_email()` | email, company_id | Resolve driver UUID from email address |
| `touch_updated_at()` | (trigger) | Auto-set `updated_at = now()` on UPDATE |

### 4.4 PostGIS & Spatial Indexing

The schema uses PostGIS geography columns (WGS84 / SRID 4326) for spatial operations:

```sql
-- Geography columns
tasks.location         geography(point, 4326)
company_members.last_known_location  geography(point, 4326)
telemetry_events.location            geography(point, 4326)

-- Spatial GiST index
CREATE INDEX idx_tasks_location ON tasks USING gist (location);
```

---

## 5. Core Algorithms

### 5.1 Nearest-Neighbour Route Optimisation

A greedy nearest-neighbour heuristic for real-time mid-shift route re-sequencing. Chosen over TSP solvers (genetic algorithms, 2-opt) for O(n²) time complexity, which is practical for mobile execution on 50+ tasks.

```
FUNCTION nearestNeighbourSequence(origin, taskPoints):
    remaining ← copy of taskPoints
    sequence  ← []
    current   ← origin

    WHILE remaining is not empty:
        nearest     ← null
        nearestDist ← ∞

        FOR EACH (taskId, point) IN remaining:
            d ← current.distanceTo(point)    // Haversine
            IF d < nearestDist:
                nearestDist ← d
                nearest     ← taskId

        sequence.append(nearest)
        current ← remaining.remove(nearest)

    RETURN sequence    // Task IDs in optimised visit order
```

**Location:** `lib/services/mapbox_service.dart` — `MapboxService.nearestNeighbourSequence()`

### 5.2 Haversine Distance Formula

Calculates great-circle distance between two geographic coordinates:

```
d = 2R × arctan2(√a, √(1−a))

where:
    a = sin²(Δlat/2) + cos(lat₁) × cos(lat₂) × sin²(Δlng/2)
    R = 6,371 km (Earth's mean radius)
```

**Location:** `lib/services/mapbox_service.dart` — `GeoPoint.distanceTo()`

### 5.3 Dynamic Priority Recalculation

Tasks are sorted by an effective priority that combines a base priority with a time-urgency bonus:

```
effectivePriority = basePriority + urgencyBonus

where urgencyBonus:
    OVERDUE    (past scheduled time)  → +50
    IMMINENT   (≤ 30 minutes away)    → +30
    APPROACHING (≤ 60 minutes away)   → +20
    UPCOMING   (≤ 120 minutes away)   → +10
    Otherwise                         → +0
```

**Sort hierarchy:** Status (pending > in-transit > delivered) → Effective Priority (desc) → Scheduled Time (asc) → Task ID.

**Location:** `lib/viewmodels/task_view_model.dart` — `computeEffectivePriority()`, `urgencyLabel()`

### 5.4 Performance-Aware Driver Recommendation

When assigning a task, the admin portal ranks available drivers using a composite score:

```
score = availabilityWeight × proximityFactor × workloadFactor × performanceFactor

where:
    availabilityWeight = 1.0 if is_available, else 0.5
    proximityFactor    = 1.0 / (1.0 + distance_km)
    workloadFactor     = 1.0 / (1.0 + current_task_count)
    performanceFactor  = 0.5 + 0.5 × completion_rate
```

**Metrics sourced from:**
- `completion_rate` = delivered tasks / total tasks (historical)
- `avg_delivery_minutes` = mean duration for completed deliveries
- `distance_km` = Haversine or PostGIS distance from driver to task

**Location:** `lib/screens/admin/admin_portal_screen.dart` — `_recommendDriver()`, plus SQL in `supabase/migrations/20260210_driver_perf_recommendation.sql`

### 5.5 Offline Sync with Exponential Backoff

When a network request fails, the mutation is enqueued to a local Drift sync queue and replayed with an exponential backoff schedule:

| Attempt | Wait Time |
|---------|-----------|
| 0 | 0 s (immediate) |
| 1 | 10 s |
| 2 | 30 s |
| 3 | 60 s |
| 4+ | 120 s |

After **5 failed attempts**, the item is marked as `failed`. On success, the queue item is deleted and the local cache is updated.

```
FUNCTION syncPendingDeliveries():
    pending ← SELECT * FROM sync_queue WHERE status = 'pending'

    FOR EACH item IN pending:
        IF backoff not elapsed: SKIP
        TRY:
            taskService.completeTask(item.taskId, item.proofCode)
            applyLocalDelivery(item.taskId)
            DELETE item from queue
        CATCH:
            INCREMENT item.attempts
            SET item.lastAttemptAt = now()
            IF item.attempts >= 5: mark 'failed'
```

**Location:** `lib/repositories/task_repository.dart` — `syncPendingDeliveries()`, `_backoffForAttempts()`

---

## 6. AI Integration (Agentic AI)

The platform integrates Large Language Models (LLMs) via OpenRouter, DeepSeek, or OpenAI for three distinct capabilities.

### 6.1 Agentic Suggestions

The AI analyses the driver's current context — task counts, driver status, time of day, and pending sync items — then returns a **structured JSON action** that can be executed with one tap.

**Available Actions:**

| Action | Effect |
|--------|--------|
| `start_next_pending` | Move next pending task to in-transit |
| `mark_delivered` | Mark a specific in-transit task as delivered |
| `go_available` | Set driver status to available |
| `go_offline` | Set driver status to offline |
| `sync_pending` | Trigger sync of offline-queued updates |
| `refresh_tasks` | Refresh the task list from server |
| `none` | Advisory suggestion only |

**Response format (LLM → Client):**
```json
{
  "suggestion": "You have 3 pending deliveries. Start with the nearest one.",
  "action": "start_next_pending",
  "task_id": null
}
```

- **Model temperature:** 0.2 (high consistency)
- **Max tokens:** 150
- **Throttle:** Minimum 5-minute interval between suggestion refreshes

**Location:** `lib/services/ai_service.dart` — `getAgenticSuggestion()`, `lib/screens/task_list/task_list_screen.dart` — `_loadAiSuggestion()`, `_executeAiAction()`

### 6.2 AI Fleet Summary

The admin portal's dashboard generates a concise natural-language summary of all active deliveries using the LLM, providing dispatchers with a quick situational overview.

- **Temperature:** 0.3
- **Max tokens:** 160
- **Output:** 2–3 bullet points with task counts and at-risk items

**Location:** `lib/services/ai_service.dart` — `summarizeTasks()`

### 6.3 Multi-Turn Chat

Both drivers and admins can engage in multi-turn conversations with the AI assistant, with optional system prompts for context grounding.

- **Temperature:** 0.4
- **Max tokens:** 200
- **History:** Full conversation context sent with each request

**Location:** `lib/services/ai_service.dart` — `chat()`

---

## 7. Driver App — User Guide

### 7.1 Authentication

1. Launch the app (default route `/`).
2. The **Driver Auth Gate** checks for an active Supabase session.
3. If not signed in, the **Login Screen** appears — enter your email and password.
4. After authentication, the system verifies:
   - You are a member of a company (`company_members` table).
   - Your role is `driver`.
5. Non-driver roles are blocked with a message and a sign-out option.

### 7.2 Task List

The main driver screen displays all assigned delivery tasks, sorted by:

1. **Status** — Pending tasks first, then in-transit, then delivered.
2. **Effective Priority** — Base priority + time-urgency bonus (see [Section 5.3](#53-dynamic-priority-recalculation)).
3. **Scheduled Time** — Earlier deadlines first.

Each task card shows:
- Destination address
- Status badge (colour-coded)
- Priority level and urgency label (OVERDUE / IMMINENT / APPROACHING / UPCOMING)
- Scheduled delivery window

**Actions:**
- **Pull to refresh** — Syncs with the server.
- **Tap a task** — View task details, mark as delivered, or open on map.
- **Mark as Delivered** — Updates status locally and remotely (or queues offline).

### 7.3 Proof of Delivery (PoD)

1. Tap the PoD action on a task.
2. Choose **Scan Barcode/QR** or **Capture Photo**.
3. The barcode scanner opens in a bottom sheet using the device camera.
4. Scanned codes and photos are saved to the `tasks` table (`proof_code`, `proof_photo_url`) and recorded as `media_artifacts`.

### 7.4 GPS Route Re-sequencing

1. Tap the **Re-sequence** floating action button (teal).
2. The app obtains your current GPS position via the Geolocator.
3. All pending/in-transit task addresses are geocoded via Mapbox.
4. The **nearest-neighbour algorithm** computes an optimised visit order from your current location.
5. The task list reorders to match the GPS-optimised sequence.
6. A banner shows when GPS override is active, with a **Clear** button to revert to priority-based sort.

### 7.5 AI Suggestions Panel

- A suggestion card appears at the bottom of the task list.
- It refreshes automatically every 5+ minutes.
- Displays a natural-language suggestion (e.g., "You have 2 pending tasks — start the nearest one.").
- An **Execute** button performs the suggested action with one tap.
- A **Dismiss** button hides the suggestion; **Refresh** fetches a new one.

### 7.6 Admin Messages

- Tap the **notification bell** icon in the app bar.
- A bottom sheet shows up to 50 recent messages (broadcast + direct).
- Unread message count is shown as a badge.
- Opening the drawer marks all messages as read.

### 7.7 Offline Mode

- If the network is unavailable, the app operates from the **local Drift cache** (SQLite on native, IndexedDB on web).
- Mutations (e.g., marking a task delivered) are **queued locally** and replayed with exponential backoff when connectivity returns.
- A **sync status strip** above the task list shows the pending queue count and a manual sync button.
- If no cache exists and no server connection is available, **demo data** loads automatically so the UI remains functional.

---

## 8. Admin Portal — User Guide

Access the admin portal by navigating to `/admin` in the browser or app.

### 8.1 Dashboard

- **Summary cards:** Pending, In-Transit, Delivered, Drivers Online, Active Routes.
- **AI Fleet Summary:** A natural-language overview generated by the LLM, summarising all current deliveries with risk indicators.
- **Task list:** All company tasks sorted by status.

### 8.2 Task Management

- **Create Task:** Enter address, select driver (by email or UUID), set status, pick scheduled date/time. The system resolves driver emails to UUIDs via the `resolve_company_member_by_email` RPC.
- **Edit Task:** Modify address, status, scheduled time, or reassign driver.
- **Delete Task:** Remove task from the database.
- **Recommend Driver:** Click the recommend button to see all company drivers ranked by the [composite recommendation score](#54-performance-aware-driver-recommendation). The dialog shows rank, email, score percentage, distance, current task count, completion rate, and average delivery time. Tap a driver to auto-fill the assignment field.

### 8.3 Route Management

- View active routes with driver assignment, vehicle, and task sequence.
- Generate **Mapbox static map previews** for each route.
- Manage route status (active, completed).

### 8.4 Fleet & Driver Management

- View all company drivers with availability status (Online/Offline).
- Monitor current task count and last GPS update time.
- Create or deactivate driver accounts.
- View per-driver performance metrics (completion rate, average delivery time).

### 8.5 CSV Bulk Import

- Upload a CSV file to bulk-create delivery tasks.
- The system parses rows using the `csv` package.
- Addresses are automatically geocoded via Mapbox.
- Tasks are batch-inserted into Supabase.

### 8.6 Proof-of-Delivery Records

- Browse historical PoD records with captured proof codes and photos.
- Filter by date range or driver.
- View or download media artifacts.

### 8.7 Admin Chat & Broadcast Messaging

- Select an individual driver to send a direct message, or toggle **broadcast** to message all drivers.
- Messages are stored in the `chat_messages` table with Supabase RLS enforcement.
- The driver app receives messages in the Admin Messages drawer.

### 8.8 Customer Tracking Lookup

- Enter an `external_ref` tracking code (customer-facing).
- The system queries the `tasks` table and returns the current status, address, scheduled time, and assigned driver.

### 8.9 Agentic Fleet Optimisation

- Global multi-driver task assignment using nearest-neighbour optimisation.
- The system geocodes all unassigned tasks, then assigns each to the nearest available driver based on the fleet-wide optimisation algorithm.

---

## 9. Getting Started

### 9.1 Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter SDK | Stable channel (≥ 3.0) | Framework |
| Dart SDK | ≥ 3.0.0, < 4.0.0 | Language |
| Android Studio / Xcode | Latest | Native toolchains |
| Supabase CLI (optional) | Latest | Local backend development |
| Git | Any | Version control |

Verify your setup:

```bash
flutter doctor
```

### 9.2 Environment Configuration

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Fill in the required values:

   | Variable | Description |
   |----------|-------------|
   | `SUPABASE_URL` | Your Supabase project URL |
   | `SUPABASE_ANON_KEY` | Supabase anonymous/public API key |
   | `SUPABASE_SERVICE_ROLE_KEY` | (Optional) Service role key for admin operations |
   | `ORDERVISTA_COMPANY_ID` | UUID of the demo company |
   | `ORDERVISTA_DRIVER_ID` | UUID of the demo driver |
   | `MAPBOX_ACCESS_TOKEN` | Mapbox API access token |
   | `MAPBOX_COUNTRY_CODE` | Country bias for geocoding (default: `hk`) |
   | `MAPBOX_PROXIMITY_LAT` | Proximity bias latitude (default: `22.3375`) |
   | `MAPBOX_PROXIMITY_LNG` | Proximity bias longitude (default: `114.1750`) |
   | `OPENROUTER_API_KEY` | API key for OpenRouter / DeepSeek / OpenAI |
   | `OPENROUTER_MODEL` | LLM model name (e.g., `deepseek/deepseek-chat`) |
   | `OPENROUTER_BASE_URL` | API base URL (e.g., `https://openrouter.ai/api/v1`) |
   | `ORDERVISTA_ENV` | `development` or `production` |
   | `ORDERVISTA_LOG_LEVEL` | Logging verbosity |

> **Note:** The `.env` file is git-ignored. Only `.env.example` is committed.

### 9.3 Build & Run

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator (with environment injection)
flutter run --dart-define-from-file=.env

# Run on web
flutter run -d chrome --dart-define-from-file=.env

# Run on web server (demo mode)
flutter run -d web-server --dart-define-from-file=.env
```

### 9.4 Code Generation (Drift ORM)

The Drift ORM requires code generation for database companion classes. Run this after modifying `lib/data/ordervista_database.dart`:

```bash
# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode (continuous regeneration during development)
dart run build_runner watch
```

### 9.5 Supabase Setup

1. Create a new Supabase project at [supabase.com](https://supabase.com).
2. Apply the database migrations in order:
   ```bash
   # Using Supabase CLI
   supabase db push

   # Or manually execute in the SQL editor:
   # 1. supabase/migrations/20251208_initial_schema.sql
   # 2. supabase/migrations/20260205_driver_availability_chat.sql
   # 3. supabase/migrations/20260210_driver_perf_recommendation.sql
   ```
3. The migrations create all tables, RLS policies, indexes, stored functions, and PostGIS extensions.
4. Create initial user accounts via Supabase Auth, then insert corresponding `company_members` rows.

---

## 10. Testing

```bash
# Run all unit and widget tests
flutter test

# Run a specific test file
flutter test test/widget_test.dart
```

The project supports `AppBootstrap.test()` factory for dependency injection in test environments.

---

## 11. Deployment

### Android

```bash
flutter build apk --release --dart-define-from-file=.env
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS

```bash
flutter build ios --release --dart-define-from-file=.env
```

### Web

```bash
flutter build web --release --dart-define-from-file=.env
# Output: build/web/
```

---

## 12. License

This project is developed as part of CS4514 Final Year Project at City University of Hong Kong. All rights reserved.

---

<div align="center">

**OrderVista** — AI-Enhanced Logistics Dispatch Platform\
CS4514 Final Year Project | City University of Hong Kong | 2025 to 2026

</div>
