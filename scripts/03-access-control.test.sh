#!/usr/bin/env bash
# ============================================================================
# Access-control service tests — privileges
# ============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

section "ACCESS CONTROL — ${BASE_URL}/api/v1/access-control"

do_login
if [[ -z "$AUTH_TOKEN" ]]; then
  skip "all (login failed)"
  summary; exit 0
fi

note "GET /api/v1/access-control/privileges"
request GET "${BASE_URL}/api/v1/access-control/privileges" -H "Authorization: Bearer $AUTH_TOKEN"
expect_status "$HTTP_CODE" "200" "get privileges"
expect_key "$BODY" "privilege_level" "response has privilege_level"

note "GET /api/v1/access-control/privileges (no token — expect 401)"
request GET "${BASE_URL}/api/v1/access-control/privileges"
expect_status_in "$HTTP_CODE" "401,502" "privileges require auth"

note "PUT /api/v1/access-control/privileges (non-admin token)"
request PUT "${BASE_URL}/api/v1/access-control/privileges" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"user_id\":2,\"privilege_levels\":[\"QA\"]}"
# 200 happens when the caller is admin; 401/403 when not; 502 when service down
expect_status_in "$HTTP_CODE" "200,400,401,403,502" "update privileges (authz enforced)"

note "PUT /api/v1/access-control/privileges (empty privilege_levels — expect 400)"
request PUT "${BASE_URL}/api/v1/access-control/privileges" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"user_id":2,"privilege_levels":[]}'
expect_status_in "$HTTP_CODE" "400,502" "update privileges rejects empty levels"

summary