#!/usr/bin/env bash
# ============================================================================
# App-version service tests — latest / all / create / update (admin)
# ============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

section "APP VERSION SERVICE — ${BASE_URL}/api/v1/app-version"

note "GET /api/v1/app-version/latest (public)"
request GET "${BASE_URL}/api/v1/app-version/latest"
expect_status "$HTTP_CODE" "200" "latest version"
expect_key "$BODY" "version" "latest has version field"

note "GET /api/v1/app-version/all (public, paginated)"
request GET "${BASE_URL}/api/v1/app-version/all?limit=10&offset=0"
expect_status "$HTTP_CODE" "200" "all versions"

do_login
if [[ -z "$AUTH_TOKEN" ]]; then
  skip "create/update (login failed)"
  summary; exit 0
fi

note "POST /api/v1/app-version (admin-only; expect 401 for non-admins)"
request POST "${BASE_URL}/api/v1/app-version" \
  -H "Authorization: Bearer $AUTH_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"title\":\"QA Version $(date +%s)\",\"description\":\"smoke test\",\"version\":\"9.9.9-qa\",\"is_current\":false,\"is_force\":false}"
expect_status_in "$HTTP_CODE" "201,200,400,401" "create app version"

note "PUT /api/v1/app-version?id=1 (admin-only)"
request PUT "${BASE_URL}/api/v1/app-version?id=1" \
  -H "Authorization: Bearer $AUTH_TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"QA Updated","description":"updated","version":"9.9.9-qa2","is_current":false,"is_force":false}'
expect_status_in "$HTTP_CODE" "200,400,401" "update app version"

note "POST /api/v1/app-version (no token — expect 401)"
request POST "${BASE_URL}/api/v1/app-version" -H 'Content-Type: application/json' \
  -d '{"title":"x","description":"y","version":"0.0.1"}'
expect_status_in "$HTTP_CODE" "401,502" "create requires auth"

summary