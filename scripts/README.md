# Satullia API — Test Scripts

Bash smoke tests covering every HTTP endpoint of the Satullia backend (auth, profile,
access-control, folders/tabs, deck, post, app-version, file, gateway).

## Setup

```bash
cd documents/scripts
cp .env.example .env
vim .env        # set BASE_URL / FILE_URL / tokens / test data
```

Defaults are tuned to the deployed environment:

```ini
BASE_URL=https://api-satullia.danials.space
FILE_URL=https://file-satullia.danials.space
FOLDER_URL=http://localhost:8080    # folders/tabs are NOT routed via the gateway yet
POST_URL=https://api-satullia.danials.space   # gateway: post checks report 404 until routing is fixed;
                                              # or use http://localhost:3003 for the service directly
TEST_EMAIL=test@gmail.com
TEST_PASSWORD=passWORD@@22
```

## Run

```bash
./run_all.sh            # everything
./run_all.sh deck auth  # only deck + auth
./run_all.sh 05 08      # by number: deck + file
```

or run a single suite:

```bash
bash 05-deck.test.sh
```

Every run writes a timestamped report to `reports/report_<timestamp>.log`.

## What each suite verifies

| Script | Service | Checks |
|---|---|---|
| `01-auth.test.sh` | Auth | login (valid/wrong/missing), refresh-token, optional signup/verify/resend (with `ENABLE_SIGNUP_TESTS=1`) |
| `02-profile.test.sh` | Profile | public lookup, own profile, update, 401 without token |
| `03-access-control.test.sh` | Access control | privileges GET, admin-only PUT, validation errors |
| `04-folder-tab.test.sh` | Folders & Tabs | featured, CRUD, save/unsave, saved, recent, search, pagination |
| `05-deck.test.sh` | Deck | all/search/featured, flashcard CRUD/search, progress, saved/recent (expected 404 today) |
| `06-post.test.sh` | Post | list/featured/search, create/update/delete with token, auth enforcement |
| `07-app-version.test.sh` | App version | latest/all, create/update (admin), auth enforcement |
| `08-file.test.sh` | File | public download (existing + missing), upload without/with token, thumbnail round-trip |
| `09-gateway.test.sh` | Gateway | status health, CORS preflight, route forwarding, unknown-prefix 404 |

## Exit codes

- `0` — all checks passed (skips allowed)
- `1` — at least one check failed
- `2` — configuration problem

## Notes / known states (at documentation time)

- `/api/v1/deck/saved` and `/api/v1/deck/recent` are **planned** endpoints; the scripts
  assert they currently return **404**.
- Auth service was unreachable (`502`) on the deployed domain during documentation — scripts
  treat `502` as "service down" and report it as an expected-possibility status, not a hard fail
  for auth-gated suites when that service is off.
- Folders/tabs: point `FOLDER_URL` at the folder-service directly (local run `go run folder-service/main.go`).
- Post service: routes registered without `/api/v1` (see `API-REFERENCE.md` §9); use `POST_URL`.
  When using the deployed gateway path, `ApiResponse` statuses `404` are expected until the
  prefix mismatch is fixed.
- File service (deployed `file-satullia.danials.space`): only GET `/api/v1/file/download/{filename}`
  is proxied. A missing file returns **200 with an HTML error page** (never 404), and
  `POST /api/v1/file/upload` returns **405 from openresty** (not proxied). Run the upload tests
  against the service directly (`http://localhost:3005`) to see the real 401 behavior.
- Unicode query params must be **percent-encoded** in URLs (raw UTF-8 is rejected upstream).