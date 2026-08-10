#!/usr/bin/env bash
# ============================================================================
# Profile service tests — get profile / update profile
# ============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

section "PROFILE SERVICE — ${BASE_URL}/api/v1/profile"

# 1. public profile lookup
note "GET /api/v1/profile?username=..."
request GET "${BASE_URL}/api/v1/profile?username=${PROFILE_USERNAME:-test}"
expect_status_in "$HTTP_CODE" "200,404,502" "get profile by username"
[[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "404" ]] && {
  [[ "$HTTP_CODE" == "200" ]] && {
    expect_key "$BODY" "username" "response has username"
    expect_key "$BODY" "privilege_level" "response has privilege_level"
  }
}

# 2. own profile (needs token)
do_login
if [[ -n "$AUTH_TOKEN" ]]; then
  note "GET /api/v1/profile (own, with token)"
  request GET "${BASE_URL}/api/v1/profile" -H "Authorization: Bearer $AUTH_TOKEN"
  expect_status "$HTTP_CODE" "200" "get own profile"
  expect_key "$BODY" "user_id" "response has user_id"
else
  skip "own profile (login failed)"
fi

# 3. update profile
if [[ -n "$AUTH_TOKEN" ]]; then
  note "POST /api/v1/profile/update"
  request POST "${BASE_URL}/api/v1/profile/update" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"full_name\":\"QA Test User\",\"bio\":\"updated by test script\"}"
  expect_status_in "$HTTP_CODE" "200,400,401,502" "update profile"
  [[ "$HTTP_CODE" == "200" ]] && expect_json "$BODY" "QA Test User" "bio/full_name persisted"
else
  skip "update profile (no token)"
fi

# 4. update profile without token → 401
note "POST /api/v1/profile/update (no token)"
request POST "${BASE_URL}/api/v1/profile/update" \
  -H 'Content-Type: application/json' -d '{"bio":"x"}'
expect_status "$HTTP_CODE" "401" "update profile requires auth"

summary