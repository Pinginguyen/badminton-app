# Project Plan

**Status**: Approved
**Created**: 2026-11-15
**Mode**: NEW

---

## 1. Project Overview

**Goal**: Build a private badminton club management mobile app for 8–25 members operating 1–3 concurrent courts, with admin-controlled session scheduling, skill-balanced doubles matchmaking, live scoring, billing, VietQR payments, attendance tracking, and optional on-device shuttle tracking for advisory insights. The project is designed so that every module is independently testable.

**App Type**: SPA + API

**API Login**: Yes

**Mode**: NEW

**Deployment Plan**: No deployment plan found

---

## 2. Supabase Platform — Backend

| Component | Technology |
|-----------|-----------|
| **Language** | SQL |
| **Runtime** | Supabase Postgres |
| **Framework** | Supabase managed BaaS |
| **Package Manager** | n/a |
| **Test Runner** | supabase db reset && supabase test |
| **Mocking Library** | n/a |
| **Test Command** | supabase db reset && supabase test |
| **Orchestration** | docker-compose |

> Supabase handles authentication, PostgreSQL, row-level security, storage, real-time subscriptions, and admin/member policy enforcement for club membership, sessions, custom billing, Elo/rating adjustments, and payment approval workflows.

## 3. Mobile App — Client

| Component | Technology |
|-----------|-----------|
| **Language** | Dart |
| **Runtime** | Dart |
| **Framework** | Flutter |
| **Package Manager** | pub |
| **Test Runner** | flutter test |
| **Mocking Library** | mocktail |
| **Test Command** | flutter test |
| **Orchestration** | docker-compose |

> The mobile client is a Flutter app for iOS and Android, designed for offline-first scoring, local caching, and resilient sync to Supabase when connectivity returns.

## 4. Services Required

| Azure Service | Role in App | Environment Variable | Default Value (Local) | Classification |
|---------------|------------|---------------------|----------------------|----------------|
| Supabase PostgreSQL | Primary relational data store for members, sessions, scores, Elo, billing, attendance, and payment status | DATABASE_URL | postgresql://postgres:postgres@localhost:5432/postgres | Essential |
| Supabase Storage | Stores avatars, match assets, generated VietQR images, and any persistent media | SUPABASE_STORAGE_URL | https://<project>.supabase.co/storage/v1 | Essential |
| Supabase Auth | Membership sign-in and role-based access for admin vs member actions | SUPABASE_URL | https://<project>.supabase.co | Essential |
| Supabase Realtime | Live scoreboard, session updates, and attendance sync across devices | SUPABASE_REALTIME_URL | wss://<project>.supabase.co/realtime/v1 | Essential |

## 5. Prerequisites

### Run

| Tool | Service(s) | Installed | Version |
|------|-----------|-----------|---------|
| Flutter SDK | Mobile App | ❓ | not detected |
| Dart SDK | Mobile App | ❓ | not detected |
| Android Studio / Android SDK | Mobile App | ❓ | not detected |
| Node.js | Supabase Platform | ✅ | v24.15.0 |
| npm | Supabase Platform | ✅ | 11.12.1 |
| Docker Desktop | Supabase Platform | ✅ | 29.1.5 |
| Docker Compose | Supabase Platform | ✅ | v5.0.1 |
| Git | * | ✅ | 2.55.0.windows.3 |
| Supabase CLI | Supabase Platform | ❓ | not detected |

### Debug

| Tool | Service(s) | Installed | Version |
|------|-----------|-----------|---------|
| Dart Code (Flutter extension) | Mobile App | ❓ | not detected |
| Flutter VS Code extension | Mobile App | ❓ | not detected |
| Docker VS Code extension | Supabase Platform | ❓ | not detected |
| VS Code TypeScript extension | local tooling | ✅ | 1.146.0 |

> Inform the user to confirm all ❓ items are installed before proceeding with local development or debugging.

## 6. Project Structure

```text
club-squad-app/
├─ supabase/
│  ├─ config.toml
│  ├─ migrations/
│  ├─ functions/
│  ├─ storage/
│  └─ seed/
├─ mobile/
│  ├─ lib/
│  ├─ test/
│  ├─ android/
│  ├─ ios/
│  ├─ pubspec.yaml
│  └─ README.md
├─ docs/
│  ├─ api-contracts.md
│  ├─ billing-rules.md
│  ├─ matchmaking-rules.md
│  └─ scoring-workflow.md
├─ .env.example
├─ .gitignore
├─ Makefile
└─ README.md
```

## 7. Route Definitions

| # | Method | Path | Description | Request Body | Response Body | Status Codes |
|---|--------|------|-------------|-------------|--------------|-------------|
| 1 | GET | `/api/health` | Health check for mobile app startup and Supabase connectivity | — | `{ status, services }` | 200, 503 |
| 2 | GET | `/rest/v1/members` | Read authenticated member roster and profile metadata | — | `Member[]` | 200, 401, 403 |
| 3 | POST | `/rest/v1/sessions` | Create or update club sessions; admin-only | `{ title, courtId, startAt, endAt, cost, capacity }` | `Session` | 200, 201, 400, 401, 403 |
| 4 | POST | `/rest/v1/matchmaking_suggestions` | Generate balanced doubles pairings with skill, rest, and repetition rules | `{ sessionId, roster, constraints }` | `MatchSuggestion[]` | 200, 400, 500 |
| 5 | POST | `/rest/v1/bills` | Compute or update member bills and attendance-weighted charges | `{ memberId, sessionId, attendance, extras, lateFee }` | `Bill` | 200, 201, 400, 401, 403 |
| 6 | POST | `/storage/v1/object/...` | Upload QR, avatar, or media attachments | binary/file metadata | `{ path, signedUrl }` | 200, 201, 400, 401 |

## 8. Next Steps

1. Run **azure-project-scaffold** to execute this plan
2. Run **azure-project-integrate** to wire the frontend to live data, smoke-test the backend, and create the migrations
3. Run **azure-debug-plan** → **azure-debug-generate** for Docker emulators and VS Code debugging
4. Run the **azure-deploy** agent when ready; it uses **azure-app-onboard** for architecture, cost estimation, IaC generation, provisioning, and health verification
