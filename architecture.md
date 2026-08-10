# Satullia Services — Architecture Overview

Stage 2/3 backend of the Satullia project. A Go (golang) micro-services monorepo at
`satullia-backend-services/`, deployed behind a gateway reverse proxy.

---

## Services at a glance

| Service | Dir | Runtime Port(s) | Transport | Purpose |
|---|---|---|---|---|
| **gateway-service** | `gateway-service` | `GATEWAY_SERVICE_PORT` (8080) | HTTP | Reverse proxy, static files, SSR, CORS |
| **auth-service** | `auth-service` | `AUTH_SERVICE_PORT` (3000) | HTTP | Signup/login, e-mail verification, JWT |
| **profile-service** | `profile-service` | `PROFILE_SERVICE_PORT` (3001) | HTTP | Profile read/update + privilege levels |
| **access-control-service** | `access-control-service` | `ACCESS_CONTROL_SERVICE_PORT` (3002) | HTTP | Privilege levels (ADMIN/SUPPORT/QA/DEMO/DEVELOPER) |
| **post-service** | `post-service` | `POST_SERVICE_PORT` (3003) | HTTP | Blog/community posts (routes registered w/o `/api/v1` prefix) |
| **app-version-service** | `app-version-service` | `APP_VERSION_SERVICE_PORT` (3004) | HTTP | App version + force-update flags |
| **file-service** | `file-service` | `FILE_SERVICE_PORT` (3005) | HTTP | Image upload/download, MinIO storage, resize variants |
| **deck-service** | no source in repo — shipped as compiled binary `folder-service/deck-service` | `DECK_SERVICE_PORT` (3006) | HTTP | Japanese-learning decks, flashcards, progress |
| **folder-service** | `folder-service` | `PORT` (default 8080) | HTTP | Folders + tabs CRUD, featured, save/recent, sync |
| **email-service** | `email-service` | `EMAIL_SERVICE_PROTO_PORT` (50051) | gRPC | Transactional e-mails (verification codes) via Postmark |

---

## Request flow

```
Browser / App
      │
      ▼
[api-satullia.danials.space] ──► gateway-service (reverse proxy)
      │  /api/v1/profile*        ──► profile-service:3001
      │  /api/v1/auth*           ──► auth-service:3000
      │  /api/v1/access-control* ──► access-control-service:3002
      │  /api/v1/post*           ──► post-service:3003
      │  /api/v1/deck*           ──► deck-service:3006
      │  /api/v1/app-version*    ──► app-version-service:3004
      │  /static/, /web/, /@{u}, /googleapis/, /status
[file-satullia.danials.space] ──► file-service:3005 (public download; upload needs JWT)
auth-service ──gRPC──► email-service:50051 (Postmark)
all services ──► PostgreSQL (shared DB)
file-service ──► MinIO bucket "satullia"
```

### Current routing gaps (verified against the deployed gateway, Feb 2026)

| Path | Result | Cause |
|---|---|---|
| `/api/v1/folders/*`, `/api/v1/tabs/*` | 404 "Service not found" | Folder-service is **not** a gateway route |
| `/api/v1/post*` | 404 | Gateway forwards the `/api/v1` prefix but post-service registers `/posts*` (no prefix) |
| `/api/v1/deck/saved`, `/api/v1/deck/recent` | 404 | Routes not shipped in the deployed deck-service binary (tables exist) |
| `/api/v1/deck/{id}` | 404 | Not registered in the deployed binary (use `/deck/all`, `/deck/featured`) |
| `/api/v1/auth/login` | 502* | Auth service unreachable at documentation time — deployed gateway has deck + app-version only |

\* The deployed gateway instance observed during documentation only served `/deck*` and
`/app-version*` + `/api/v1/deck/*` successfully; the repo gateway (newer) has the full route
table above.

## Cross-cutting concerns

- **Common package** (`common/`): JWT create/validate (`token_utils.go`), user-ID extraction from
  `Authorization: Bearer` (`userid_from_token.go`), response helpers
  (`response_utils.go` — `SendErrorResponse`, `SendJSONError`, `SendJSONResponse`,
  pagination parsing), middleware (`middleware/`):
  - `LoggedInMiddleware` — validates token, stores userID in context
  - `AdminOnly` — validates token + ADMIN privilege (note: contains an inverted check bug —
    non-admins currently pass; flagged to backend team)
  - `Logging`, `FileLogging`, `JsonLogging`, `ElasticsearchLogging`
- **Shared model** (`model/`): repositories + entities (Folder, Tab, Post, Profile, User,
  UserPrivilege, AppVersion, UploadedFile, FolderShare, SyncChange, VerificationCode, ...)
- **CORS**: gateway allows all origins, headers `Authorization, Content-Type, Accept, Origin,
  User-Agent, Cache-Control, X-Requested-With, X-Auth-Token`, exposes `X-Auth-Token`.
- **Databases**: single PostgreSQL instance (see `docker-compose-postgres.yml`); emails via
  Postmark; files via MinIO.
- **Deployment**: `docker-compose-services.yml` (services run in container `satullia-network-prod`),
  `build_services.sh`, `docker-compose-prod.yml`. Note: compose references a `./deck-service`
  build dir that does not exist in the repo (deck-service ships as a binary).

## Local startup

```bash
# from satullia-backend-services/
cp .env .env.local          # edit ports/hosts
go run auth-service/main.go        # :3000
go run profile-service/main.go     # :3001
go run access-control-service/main.go
go run post-service/main.go        # :3003
go run app-version-service/main.go # :3004
go run file-service/main.go        # :3005
go run folder-service/main.go      # :8080 (folders/tabs)
./folder-service/deck-service      # :3006 (deck)
go run gateway-service/main.go     # :8080 gateway (if ports conflict, adjust env)
```

## Hosts in production (as used by the front-end team)

| Domain | Service |
|---|---|
| `https://api-satullia.danials.space` | gateway + routed APIs |
| `https://file-satullia.danials.space` | file service |

See `API-REFERENCE.md` for every endpoint and `swagger/satullia-api.yaml` for the OpenAPI spec.