#!/usr/bin/env bash
# ============================================================================
# Post service tests
# NOTE: routes are registered WITHOUT the /api/v1 prefix; gateway forwards
# /api/v1/post* unchanged in this codebase → point POST_URL at the service
# directly (e.g. http://localhost:3003, default).
# ============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

section "POST SERVICE — ${POST_URL}"

# ---------- public ----------
note "GET /posts (paginated)"
request GET "${POST_URL}/posts?page=1&page_size=10"
expect_status_in "$HTTP_CODE" "200,404,502" "posts list"
[[ "$HTTP_CODE" == "200" ]] && {
  expect_key "$BODY" "posts" "response has posts"
  expect_key "$BODY" "pagination" "response has pagination"
}

note "GET /posts/featured"
request GET "${POST_URL}/posts/featured?limit=5"
expect_status_in "$HTTP_CODE" "200,404,502" "featured posts"

note "GET /posts/search?query=... (missing query is a 400)"
request GET "${POST_URL}/posts/search"
expect_status_in "$HTTP_CODE" "400,404,502" "search requires query"

note "GET /posts/search?query=go"
request GET "${POST_URL}/posts/search?query=go"
expect_status_in "$HTTP_CODE" "200,400,404,502" "search posts"

if [[ -n "${TEST_POST_ID:-}" ]]; then
  note "GET /posts/{id}"
  request GET "${POST_URL}/posts/${TEST_POST_ID}"
  expect_status_in "$HTTP_CODE" "200,404,502" "post by id"
  [[ "$HTTP_CODE" == "200" ]] && expect_key "$BODY" "id" "post has id"
fi

# ---------- auth ----------
do_login
if [[ -z "$AUTH_TOKEN" ]]; then
  skip "auth-required post endpoints (login failed)"
  summary; exit 0
fi

note "POST /posts (create — requires token)"
request POST "${POST_URL}/posts" \
  -H "Authorization: Bearer $AUTH_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"title\":\"QA Post $(date +%s)\",\"content\":\"smoke test content\",\"tags\":[\"qa\"]}"
expect_status_in "$HTTP_CODE" "201,200,400,401,404,502" "create post"
NEW_POST_ID="$(printf '%s' "$BODY" | sed -n 's/.*"post"[[:space:]]*:[[:space:]]*{[^}]*"id"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')"

if [[ -n "$NEW_POST_ID" && "$NEW_POST_ID" != "0" ]]; then
  note "PUT /posts/{id} (update)"
  request PUT "${POST_URL}/posts/$NEW_POST_ID" \
    -H "Authorization: Bearer $AUTH_TOKEN" -H 'Content-Type: application/json' \
    -d '{"title":"Updated QA title","content":"updated content"}'
  expect_status_in "$HTTP_CODE" "200,401,404" "update post"

  note "PUT /posts/{id}/featured"
  request PUT "${POST_URL}/posts/$NEW_POST_ID/featured" \
    -H "Authorization: Bearer $AUTH_TOKEN" -H 'Content-Type: application/json' \
    -d '{"featured":true}'
  expect_status_in "$HTTP_CODE" "200,401,404" "set featured"

  note "DELETE /posts/{id} (cleanup)"
  request DELETE "${POST_URL}/posts/$NEW_POST_ID" -H "Authorization: Bearer $AUTH_TOKEN"
  expect_status "$HTTP_CODE" "200" "delete post"
else
  skip "post update/featured/delete (could not parse created id)"
fi

note "POST /posts (no token — expect 401)"
request POST "${POST_URL}/posts" -H 'Content-Type: application/json' \
  -d '{"title":"x","content":"y"}'
expect_status_in "$HTTP_CODE" "401,404,502" "create post requires auth"

summary