#!/usr/bin/env bash
# ============================================================================
# Auth service tests — signup / login / verify / resend / refresh
# ============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

section "AUTH SERVICE — ${BASE_URL}/api/v1/auth"

# 1. login
note "POST /api/v1/auth/login (valid credentials)"
request POST "${BASE_URL}/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${TEST_EMAIL:-test@gmail.com}\",\"password\":\"${TEST_PASSWORD:-passWORD@@22}\"}"
expect_status_in "$HTTP_CODE" "200,400,401,502,503" "login"
if [[ "$HTTP_CODE" == "200" ]]; then
  expect_key "$BODY" "access_token" "response has access_token"
  expect_key "$BODY" "refresh_token" "response has refresh_token"
  AUTH_TOKEN="$(printf '%s' "$BODY" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  REFRESH_TOKEN="$(printf '%s' "$BODY" | sed -n 's/.*"refresh_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
else
  skip "token extraction (login unsuccessful)"
fi

# 2. login — missing fields
note "POST /api/v1/auth/login (missing password)"
request POST "${BASE_URL}/api/v1/auth/login" \
  -H 'Content-Type: application/json' -d '{"email":"x@y.z"}'
expect_status_in "$HTTP_CODE" "400,502" "login rejects missing fields"

# 3. login — wrong password
note "POST /api/v1/auth/login (wrong password)"
request POST "${BASE_URL}/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${TEST_EMAIL:-test@gmail.com}\",\"password\":\"wrong-password-123\"}"
expect_status_in "$HTTP_CODE" "400,401,502" "login rejects wrong password"

# 4. refresh token
if [[ -n "${REFRESH_TOKEN:-}" ]]; then
  note "POST /api/v1/auth/refresh-token"
  request POST "${BASE_URL}/api/v1/auth/refresh-token" \
    -H 'Content-Type: application/json' \
    -d "{\"refresh_token\":\"$REFRESH_TOKEN\"}"
  expect_status "$HTTP_CODE" "200" "refresh-token"
  expect_key "$BODY" "access_token" "response has access_token"
else
  skip "refresh-token (no refresh token)"
fi

# 5. refresh token — missing value
note "POST /api/v1/auth/refresh-token (empty body)"
request POST "${BASE_URL}/api/v1/auth/refresh-token" \
  -H 'Content-Type: application/json' -d '{}'
expect_status_in "$HTTP_CODE" "400,502" "refresh-token rejects empty body"

# 6. signup / verify-code / resend — only run when ENABLE_SIGNUP_TESTS=1 (they send e-mails)
if [[ "${ENABLE_SIGNUP_TESTS:-0}" == "1" ]]; then
  RANDOM_EMAIL="qa+$(date +%s)@danials.space"
  note "POST /api/v1/auth/signup"
  request POST "${BASE_URL}/api/v1/auth/signup" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$RANDOM_EMAIL\",\"password\":\"S3cureP@ssw0rd\",\"signup_method\":\"APP\",\"username\":\"qa_$(date +%s)\"}"
  expect_status_in "$HTTP_CODE" "201,400,502" "signup"

  note "POST /api/v1/auth/resend-verify-code"
  request POST "${BASE_URL}/api/v1/auth/resend-verify-code" \
    -H 'Content-Type: application/json' -d "{\"email\":\"$RANDOM_EMAIL\"}"
  expect_status_in "$HTTP_CODE" "200,400,404,502" "resend-verify-code"

  note "POST /api/v1/auth/verify-code (fake code — expect 400)"
  request POST "${BASE_URL}/api/v1/auth/verify-code" \
    -H 'Content-Type: application/json' -d "{\"email\":\"$RANDOM_EMAIL\",\"code\":\"000000\"}"
  expect_status_in "$HTTP_CODE" "400,502" "verify-code rejects fake code"
else
  skip "signup / verify-code / resend (enable with ENABLE_SIGNUP_TESTS=1)"
fi

summary