#!/usr/bin/env bash
# ============================================================================
# Gateway service tests — health, routing, static/SSR
# ============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

section "GATEWAY — ${BASE_URL}"

note "HEAD /status (health)"
HTTP_CODE="$(curl -s -m 15 -o /dev/null -w '%{http_code}' -I "${BASE_URL}/status")"
expect_status "$HTTP_CODE" "200" "gateway health (HEAD only)"

note "GET /status (non-HEAD → 405)"
request GET "${BASE_URL}/status"
expect_status "$HTTP_CODE" "405" "status rejects GET"

note "CORS preflight"
HTTP_CODE="$(curl -s -m 15 -o /dev/null -w '%{http_code}' -X OPTIONS "${BASE_URL}/api/v1/deck/all" \
  -H 'Origin: https://example.com' -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: Authorization,Content-Type')"
expect_status_in "$HTTP_CODE" "200,204" "CORS preflight accepted"

note "routing: /api/v1/deck/all via gateway"
request GET "${BASE_URL}/api/v1/deck/all?offset=1&limit=1"
expect_status "$HTTP_CODE" "200" "deck routed via gateway"

note "routing: /api/v1/app-version/latest via gateway"
request GET "${BASE_URL}/api/v1/app-version/latest"
expect_status "$HTTP_CODE" "200" "app-version routed via gateway"

note "routing: unknown /api/v1/xxx → 404"
request GET "${BASE_URL}/api/v1/definitely-not-a-service"
expect_status "$HTTP_CODE" "404" "unknown service prefix → 404"

if [[ "$HTTP_CODE" == "404" ]]; then :; fi
summary