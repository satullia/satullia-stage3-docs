# Satullia Backend — API Documentation & Test Scripts

Documentation-only package for the Satullia backend (auth, profile, access-control,
folders, tabs, deck, post, app-version, file, gateway). No application code was changed.

## Contents

| Path | Description |
|---|---|
| `swagger/satullia-api.yaml` | **OpenAPI 3.0.3 spec** — the source of truth for the front-end team. 49 paths, 33 schemas. Import into Swagger UI / Postman / Insomnia. |
| `API-REFERENCE.md` | Human-readable endpoint reference: methods, query/path/body params, auth, examples, known gaps. |
| `architecture.md` | Service map with ports, gateway routing rules, request flow, local start commands, production hosts. |
| `scripts/` | Ready-to-run Bash smoke tests for every endpoint (`./run_all.sh` or per-service). See `scripts/README.md`. |
| `postman/satullia.postman_collection.json` | Postman collection mirroring the Swagger spec (folder-organized requests). |

## Quick start

```bash
# 1. Swagger — view online or locally
open https://editor.swagger.io   # paste contents of swagger/satullia-api.yaml

# 2. Smoke tests
cd scripts
cp .env.example .env            # defaults point at the deployed environment
./run_all.sh                    # or: ./run_all.sh deck auth

# 3. Postman
#   Import postman/satullia.postman_collection.json and set the
#   {{base_url}} collection variable to https://api-satullia.danials.space
```

## Environment matrix

| Env | Base URL |
|---|---|
| Production API | `https://api-satullia.danials.space` |
| Production Files | `https://file-satullia.danials.space` |
| Local (docker compose) | `http://localhost:8080` (gateway) |

## Known gaps (documented, not fixed)

- `/api/v1/deck/saved` and `/api/v1/deck/recent` are planned but not yet implemented (return 404).
- Gateway does not route `folders`, `profile`, `post` prefixes today (404 `Service not found`).
- Post service registers routes without the `/api/v1` prefix — reach it directly on `:3003` or via `POST_URL` in tests.
- Auth service returned 502 on the deployed domain at documentation time — retried/treated as "service down" in tests.

Full details in `API-REFERENCE.md` and `architecture.md`.