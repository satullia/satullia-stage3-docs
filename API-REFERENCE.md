# Satullia API Reference

Complete reference of every HTTP endpoint in the Satullia backend (stage 2 / stage 3 services).

Machine-readable spec: [`swagger/satullia-api.yaml`](swagger/satullia-api.yaml)

---

## 1. Hosts & Base URLs

| Environment | Base URL | Used for |
|---|---|---|
| Deployed API | `https://api-satullia.danials.space` | Gateway-routed services (auth, profile, access-control, post, deck, app-version) |
| Deployed file | `https://file-satullia.danials.space` | File service (upload/download) |
| Local gateway | `http://localhost:8080` | All gateway-routed services |
| Local direct | `http://localhost:3000..3006` | Individual services (ports below) |

### Service ports (from `.env`)

| Service | Env var | Default port |
|---|---|---|
| Gateway | `GATEWAY_SERVICE_PORT` | `8080` |
| Auth | `AUTH_SERVICE_PORT` | `3000` |
| Profile | `PROFILE_SERVICE_PORT` | `3001` |
| Access Control | `ACCESS_CONTROL_SERVICE_PORT` | `3002` |
| Post | `POST_SERVICE_PORT` | `3003` |
| App Version | `APP_VERSION_SERVICE_PORT` | `3004` |
| File | `FILE_SERVICE_PORT` | `3005` |
| Deck | `DECK_SERVICE_PORT` | `3006` |
| Email (gRPC, internal) | `EMAIL_SERVICE_PROTO_PORT` | `50051` |

---

## 2. Authentication

- **Type:** JWT (HS256), sent as `Authorization: Bearer <access_token>`.
- **Access token:** valid 30 days. **Refresh token:** valid 90 days.
- Obtain tokens via `POST /api/v1/auth/login`, `POST /api/v1/auth/verify-code` or refresh via `POST /api/v1/auth/refresh-token`.
- Claims: `{"user_id": "<id>", "exp": ..., "iat": ...}`.

### Standard error shapes

```json
{ "error": { "code": "ERROR_INVALID_EMAIL_OR_PASSWORD", "message": "Invalid email or password" } }
```
Some services (folder/tab) return a simpler shape:
```json
{ "error": "Folder title is required" }
```

---

## 3. Auth Service

### POST /api/v1/auth/signup
Create a user + profile + verification code (e-mailed). Optional fields are nullable pointers.

```json
{
  "email": "user@example.com",
  "password": "S3cureP@ssw0rd",
  "signup_method": "APP",
  "fullname": "John Doe",
  "username": "johndoe",
  "bio": "Hello",
  "image_url": ""
}
```
- `signup_method` enum: `APP | GOOGLE | APPLE | WHATSAPP`
- `201` → `{"message": "User successfully registered"}`
- `400` → duplicate email/username, missing fields

### POST /api/v1/auth/login
```json
{ "email": "user@example.com", "password": "S3cureP@ssw0rd" }
```
- `200` → `{"access_token": "...", "refresh_token": "..."}`
- `400` bad credentials, `401` email not verified

### POST /api/v1/auth/verify-code
```json
{ "email": "user@example.com", "code": "123456" }
```
- `200` → `{"access_token": "...", "refresh_token": "..."}` (marks user verified)
- `400` wrong/expired code, `404` unknown user

### POST /api/v1/auth/resend-verify-code
```json
{ "email": "user@example.com" }
```
- `200` → `{"message": "Verification code resent"}`

### POST /api/v1/auth/refresh-token
```json
{ "refresh_token": "..." }
```
- `200` → `{"access_token": "..."}`

---

## 4. Profile Service

### GET /api/v1/profile
- `?username=johndoe` → public lookup (no token needed).
- No username → returns the authenticated user's own profile.

`200` →
```json
{
  "id": 1, "user_id": 1, "username": "johndoe", "full_name": "John Doe",
  "bio": "Hello", "image_url": "",
  "created_at": "2025-03-26T06:04:59.394518Z", "updated_at": "2025-03-26T06:04:59.394518Z",
  "privilege_level": ["ADMIN"]
}
```

### POST /api/v1/profile/update  🔒
```json
{ "full_name": "John", "bio": "New bio", "image_url": "826c7d5b-e231-4be1-8bc9-5db6e3ecec46" }
```
All fields optional. `200` → updated profile object (same shape as above, without `privilege_level`).

---

## 5. Access Control Service

Privilege levels: `ADMIN | SUPPORT | QA | DEMO | DEVELOPER`

### GET /api/v1/access-control/privileges  🔒
`200` → array of:
```json
{
  "id": 1, "user_id": 1, "privilege_level": ["ADMIN"], "given_by": 1,
  "created_at": "...", "updated_at": "...", "deleted_at": "..."
}
```
Empty array `[]` when the user has no privileges.

### PUT /api/v1/access-control/privileges  🔒 (admin only)
```json
{ "user_id": 2, "privilege_levels": ["DEVELOPER", "QA"] }
```
`200` → `{"message": "Privileges updated successfully"}`

---

## 6. Folder Service — Folders

> ⚠️ Currently **not routed through the deployed gateway** — call the folder-service directly (local port 8080/`PORT` env) until the gateway is extended.

### GET /api/v1/folders/all 🔒
Query: `page` (default 1), `pageSize` (default 10).
`200` →
```json
{
  "folders": [ ...Folder... ],
  "pagination": {
    "total_count": 42, "total_pages": 5, "current_page": 1,
    "page_size": 10, "has_next_page": true, "has_previous_page": false
  }
}
```

### GET /api/v1/folders/{id} 🔒
`200` → Folder object. Records the folder as "recently viewed" for the token user.

### POST /api/v1/folders 🔒
Body: Folder (see below). `cover_image_id` defaults to `default_folder_cover.jpg`; `is_active=true`, `tab_count=0` are forced.
`201` → `{"message": "Folder created successfully", "folder": {...}}`

### PUT /api/v1/folders 🔒
Body must include `id`. `201`-style response → `{"message": ..., "folder": {...}}`.

### DELETE /api/v1/folders/{id} 🔒
Owner only. `200` → `{"message": "Folder deleted successfully"}`. `403` if not the owner.

### GET /api/v1/folders/search 🔒
Query: `query` (required). `200` → Folder array.

### GET /api/v1/folders/featured/all (public)
`200` → featured folder rows array.

### GET /api/v1/folders/featured/{id} (public)
`200` → `{"is_featured": true|false}`

### POST /api/v1/folders/featured/{id} 🔒
Optional `?order=`. `200` → `{"message": "Folder added to featured successfully"}`

### DELETE /api/v1/folders/featured/{id} 🔒
`200` → `{"message": "Folder removed from featured successfully"}`

### Folder object
```json
{
  "id": 1, "title": "My folder", "description": "...", "category": "WORK",
  "level": "", "image_ids": ["826c7d5b-..."], "cover_image_id": "default_folder_cover.jpg",
  "is_active": true, "inserted_by": 1, "tab_count": 0, "difficulty": 0,
  "tags": ["go"], "color": "#8BC34A",
  "created_at": "...", "updated_at": "..."
}
```
`category` enum: `WORK | PERSONAL | EDUCATION | OTHER`

---

## 7. Folder Service — Tabs

### GET /api/v1/tabs/{id}
`200` → Tab + `is_saved`. Tracks "recently viewed" when authenticated.

### GET /api/v1/tabs (paginated)
Query: `page`, `pageSize`.
`200` → `{"data": [Tab+is_saved...], "pagination": {...}}` (pagination like folders).

### GET /api/v1/tabs/folder/{folder_id}
`200` → `[Tab+is_saved...]`

### GET /api/v1/tabs/search
Query: `q` (required), optional `page`, `pageSize`. → `[Tab+is_saved...]`

### POST /api/v1/tabs 🔒
Body `InsertTabRequest` → `201` Tab object.
```json
{
  "title": "OpenCode", "description": "CLI", "url": "https://opencode.ai",
  "folder_id": 1, "tags": ["cli"],
  "notes": [{ "content": "a note" }],
  "files": [{ "uploaded_file_id": "826c7d5b-e231-4be1-8bc9-5db6e3ecec46" }]
}
```
`title` and `url` required.

### PUT /api/v1/tabs 🔒
**Tab ID comes from `?id=` query param.** Body = `InsertTabRequest`. Notes with `id` are updated; files with `id=0` are added. `200` → Tab.

### DELETE /api/v1/tabs/{id} 🔒
`200` → `{"success": true, "message": "Tab deleted successfully"}`

### POST /api/v1/tabs/{id}/save 🔒
`200` → `{"success": true, "message": "Tab saved successfully", "tab": {...}}`

### DELETE /api/v1/tabs/{id}/unsave 🔒
`200` → `{"success": true, "message": "Tab unsaved successfully", "tab": {...}}`

### GET /api/v1/tabs/saved 🔒
`200` → `[{"tab_id": 1, "tab": {...}, "is_saved": true}]`

### GET /api/v1/tabs/recent 🔒
`200` → `[{"tab_id": 1, "tab": {...}, "is_saved": false, "last_viewed_at": "..."}]`

### Tab object
```json
{
  "id": 1, "folder_id": 1, "url": "https://...", "title": "T", "description": "",
  "tags": [], "inserted_by": 1, "deleted_at": null,
  "created_at": "...", "updated_at": "...",
  "notes": [{"id":1,"tab_id":1,"content":"...","created_at":"...","updated_at":"..."}],
  "files": [{"id":1,"tab_id":1,"uploaded_file_id":"...","created_at":"...","uploaded_at":"..."}]
}
```

---

## 8. Deck Service

> Served by the compiled `deck-service` binary (currently deployed behind the gateway, port 3006).
> Verified live responses are included where the deployed service was reachable.

### GET /api/v1/deck/all (public)
Query: `offset` (default 1), `limit` (default 10).
`200` →
```json
{
  "data": [
    {
      "id": 50, "title": "Common Places", "description": "...", "category": "VOCABULARY",
      "level": "N5", "image_ids": ["826c7d5b-e231-4be1-8bc9-5db6e3ecec46"],
      "cover_image_id": "826c7d5b-e231-4be1-8bc9-5db6e3ecec46",
      "is_active": true, "inserted_by": 1, "card_count": 2, "difficulty": 2,
      "tags": ["place"], "color": "#8BC34A",
      "created_at": "...", "updated_at": "...", "is_saved": false
    }
  ],
  "pagination": { "limit": 10, "offset": 1, "total": 17 }
}
```

### GET /api/v1/deck/search (public)
Query: `query`. `200` → Deck array.

### GET /api/v1/deck/featured (public)
`200` →
```json
{
  "success": true, "message": "Featured decks retrieved successfully",
  "data": [
    { "id": 1, "deck_id": 51, "display_order": 1, "added_at": "...", "deck": { ...Deck... } }
  ]
}
```

### POST /api/v1/deck 🔒
Body: Deck (title required). `201` → Deck. (401 without token.)

### PUT /api/v1/deck 🔒
Body: Deck including `id`. `200` → Deck.

### POST /api/v1/deck/{id}/activate 🔒
### POST /api/v1/deck/{id}/deactivate 🔒
`200` → `{"message": "..."}`

### GET /api/v1/deck/flashcard/{id} (public)
`200` →
```json
{
  "id": 5, "deck_id": 45, "japanese": "頭", "furigana": "あたま", "romaji": "atama",
  "meaning": "Head", "example": "頭が痛いです。", "example_meaning": "I have a headache.",
  "type": "VOCABULARY", "level": "N5", "writing_system": "KANJI",
  "audio_url": "", "image_url": "", "tags": ["body", "health"], "notes": "",
  "inserted_by": 1, "created_at": "...", "updated_at": "..."
}
```

### GET /api/v1/deck/flashcard/deck/{deck_id} (public)
`200` → Flashcard array.

### GET /api/v1/deck/flashcard/search (public)
Query: `query`. `200` → Flashcard array.

### POST /api/v1/deck/flashcard 🔒 / PUT /api/v1/deck/flashcard 🔒
Create / update a flashcard (`id` in body for update).

### POST /api/v1/deck/progress/record 🔒
Body sample (learning_progress): `{"user_id": 1, "flashcard_id": 5, "is_correct": true, "proficiency": 3}`

### GET /api/v1/deck/progress/user/{user_id}/due 🔒
Due flashcards for spaced repetition

### GET /api/v1/deck/progress/user/{user_id}/deck/{deck_id} 🔒
`200` → deck progress: `{id, user_id, deck_id, cards_completed, total_cards, average_proficiency, last_accessed_at}`

### Planned (NOT implemented in the deployed binary — HTTP 404 today)
| Route | Status |
|---|---|
| `GET /api/v1/deck/saved` | 🔴 404 — `saved_decks` table exists, route not shipped |
| `GET /api/v1/deck/recent` | 🔴 404 — `recent_decks` table exists, route not shipped |

### Deck tables (created by the service on boot)
`decks`, `flashcards`, `learning_progress`, `deck_progress`, `saved_decks`, `recent_decks`, `featured_decks`.

---

## 9. Post Service

> ⚠️ Routes are registered **without** the `/api/v1` prefix (`/posts...`) in `routes.go`, while the
> gateway forwards `/api/v1/post*` unchanged — the prefix mismatch makes them unreachable through
> the gateway until aligned. Use the post-service port directly for now.

| Method | Route | Auth | Description |
|---|---|---|---|
| POST | `/posts` | 🔒 | Create (title + content required) → `201 {message, post}` |
| GET | `/posts` | – | Paginated; query `page`, `page_size`, `category_id`, `featured` → `{posts, pagination:{current_page,page_size,total_items,total_pages}}` |
| GET | `/posts/{id}` | – | Get one |
| PUT | `/posts/{id}` | 🔒 author | Update title/content/image_url/category_id/tags |
| DELETE | `/posts/{id}` | 🔒 author | Delete → `{message}` |
| GET | `/posts/featured` | – | Query `limit` (default 10) |
| PUT | `/posts/{id}/featured` | 🔒 | Body `{"featured": true}` → `{message}` |
| GET | `/posts/search` | – | Query `query` (required) → posts array |

---

## 10. App Version Service

| Method | Route | Auth | Description |
|---|---|---|---|
| GET | `/api/v1/app-version/latest` | – | Current version → AppVersion object |
| GET | `/api/v1/app-version/all` | – | Query `limit` (default 10), `offset` (default 0) → AppVersion array |
| POST | `/api/v1/app-version` | 🔒 admin | Create; flips all others `is_current=false` → `201` AppVersion |
| PUT | `/api/v1/app-version?id=` | 🔒 admin | Update (ID from query) → `200` AppVersion |

```json
{ "title": "Release 2", "description": "New features", "version": "1.1.0", "is_current": true, "is_force": false }
```
`200` example: `{"id":1,"is_current":true,"is_force":true,"title":"first version","description":"","version":"1.0.1",...}`

---

## 11. File Service

> Deployed at `https://file-satullia.danials.space`. MinIO bucket: `satullia`.

### POST /api/v1/file/upload 🔒
`multipart/form-data`, field name **`file`** (an image).
On success it stores the original + generated variants:
`<uuid>`, `<uuid>_preview` (1000px), `<uuid>_thumbnail` (400px), `<uuid>_icon` (100px).
`201` →
```json
{ "id": 1, "name": "826c7d5b-e231-4be1-8bc9-5db6e3ecec46", "user_id": 1, "created_at": "...", "deleted_at": "..." }
```
`400` for non-image / missing file.

### GET /api/v1/file/download/{filename} (public)
Example: `/api/v1/file/download/826c7d5b-e231-4be1-8bc9-5db6e3ecec46_thumbnail`
Streams the object (Content-Type from MinIO). `404` when missing.

---

## 12. Gateway Service conventions

- `/api/v1/<service>/...` → reverse-proxied per table in the docs overview.
- `/status` — HEAD only, `200` = healthy.
- `/@{username}` — SSR HTML profile page.
- `/static/`, `/web/`, `/googleapis/` — static assets and Google Maps proxy.
- Unknown API paths → `404` ("Service not found" / custom 404 page).

---

## 13. Auth-required routes quick checklist (🔒)

| Service | Endpoints |
|---|---|
| Profile | `GET /api/v1/profile` (no username), `POST /api/v1/profile/update` |
| Access control | `GET` + `PUT /api/v1/access-control/privileges` |
| Folders | all except `featured/all` + `featured/{id}` GET |
| Tabs | POST/PUT/DELETE, save/unsave, saved, recent |
| Deck | create/update deck, activate/deactivate, flashcards create/update, progress |
| Post | create, update, delete, set featured |
| App version | POST/PUT |
| File | upload |

## 14. Test scripts

Bash smoke tests live in [`scripts/`](scripts/README.md) — configure `documents/scripts/.env`, then run `./run_all.sh`.