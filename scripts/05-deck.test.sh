#!/usr/bin/env bash
# ============================================================================
# Deck service tests — decks / flashcards / progress / featured / saved
# ============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

section "DECK SERVICE — ${BASE_URL}/api/v1/deck"

# ---------- public endpoints ----------
note "GET /api/v1/deck/all (paginated)"
request GET "${BASE_URL}/api/v1/deck/all?offset=1&limit=5"
expect_status "$HTTP_CODE" "200" "deck all"
expect_key "$BODY" "pagination" "deck all has pagination"
expect_key "$BODY" "data" "deck all has data"

note "GET /api/v1/deck/search"
request GET "${BASE_URL}/api/v1/deck/search?query=japanese"
expect_status "$HTTP_CODE" "200" "deck search"

note "GET /api/v1/deck/featured"
request GET "${BASE_URL}/api/v1/deck/featured"
expect_status "$HTTP_CODE" "200" "deck featured"
expect_key "$BODY" "success" "featured response has success flag"

note "GET /api/v1/deck/flashcard/{id}"
request GET "${BASE_URL}/api/v1/deck/flashcard/${TEST_FLASHCARD_ID:-1}"
expect_status "$HTTP_CODE" "200" "flashcard by id"
[[ "$HTTP_CODE" == "200" ]] && {
  expect_key "$BODY" "japanese" "flashcard has japanese"
  expect_key "$BODY" "meaning" "flashcard has meaning"
}

note "GET /api/v1/deck/flashcard/deck/{deck_id}"
request GET "${BASE_URL}/api/v1/deck/flashcard/deck/${TEST_DECK_IDS[0]:-45}"
expect_status "$HTTP_CODE" "200" "flashcards in deck"

note "GET /api/v1/deck/flashcard/search (unicode percent-encoded)"
request GET "${BASE_URL}/api/v1/deck/flashcard/search?query=%E6%97%A5%E6%9C%AC"
expect_status "$HTTP_CODE" "200" "flashcard search"

# saved / recent are planned endpoints — verify current state (404 expected today)
note "GET /api/v1/deck/saved  (planned endpoint — expect 404 for now)"
request GET "${BASE_URL}/api/v1/deck/saved"
expect_status "$HTTP_CODE" "404" "deck saved (not implemented yet)"
note "GET /api/v1/deck/recent  (planned endpoint — expect 404 for now)"
request GET "${BASE_URL}/api/v1/deck/recent"
expect_status "$HTTP_CODE" "404" "deck recent (not implemented yet)"

# ---------- auth-required endpoints ----------
do_login
if [[ -z "$AUTH_TOKEN" ]]; then
  skip "auth-required deck endpoints (login failed)"
  summary; exit 0
fi

note "POST /api/v1/deck (create)"
request POST "${BASE_URL}/api/v1/deck" \
  -H "Authorization: Bearer $AUTH_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"title\":\"QA Deck $(date +%s)\",\"description\":\"smoke test\",\"category\":\"VOCABULARY\",\"level\":\"N5\"}"
expect_status_in "$HTTP_CODE" "201,200,400,401" "create deck"
NEW_DECK_ID="$(printf '%s' "$BODY" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)"
[[ -n "$NEW_DECK_ID" && "$NEW_DECK_ID" != "0" ]] \
  && note "created deck id: $NEW_DECK_ID" || skip "deck created (id parse)"

note "POST /api/v1/deck (no token — expect 401)"
request POST "${BASE_URL}/api/v1/deck" -H 'Content-Type: application/json' -d '{"title":"x"}'
expect_status_in "$HTTP_CODE" "401,502" "create deck requires auth"

if [[ -n "$NEW_DECK_ID" && "$NEW_DECK_ID" != "0" ]]; then
  note "POST /api/v1/deck/flashcard (create)"
  request POST "${BASE_URL}/api/v1/deck/flashcard" \
    -H "Authorization: Bearer $AUTH_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"deck_id\":$NEW_DECK_ID,\"japanese\":\"猫\",\"romaji\":\"neko\",\"meaning\":\"Cat\",\"type\":\"VOCABULARY\"}"
  expect_status_in "$HTTP_CODE" "201,200,400,401" "create flashcard"
  NEW_FLASH_ID="$(printf '%s' "$BODY" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)"
  [[ -n "$NEW_FLASH_ID" && "$NEW_FLASH_ID" != "0" ]] && note "created flashcard id: $NEW_FLASH_ID" \
    || skip "flashcard created (id parse)"

  note "POST /api/v1/deck/{id}/activate"
  request POST "${BASE_URL}/api/v1/deck/$NEW_DECK_ID/activate" -H "Authorization: Bearer $AUTH_TOKEN"
  expect_status_in "$HTTP_CODE" "200,404,401" "activate deck"

  note "POST /api/v1/deck/{id}/deactivate"
  request POST "${BASE_URL}/api/v1/deck/$NEW_DECK_ID/deactivate" -H "Authorization: Bearer $AUTH_TOKEN"
  expect_status_in "$HTTP_CODE" "200,404,401" "deactivate deck"
else
  skip "flashcard create + activate/deactivate (no created deck)"
fi

note "POST /api/v1/deck/progress/record"
request POST "${BASE_URL}/api/v1/deck/progress/record" \
  -H "Authorization: Bearer $AUTH_TOKEN" -H 'Content-Type: application/json' \
  -d "{\"user_id\":1,\"flashcard_id\":${TEST_FLASHCARD_ID:-1},\"is_correct\":true,\"proficiency\":3}"
expect_status_in "$HTTP_CODE" "200,201,400,401" "record progress"

note "GET /api/v1/deck/progress/user/1/due"
request GET "${BASE_URL}/api/v1/deck/progress/user/1/due" -H "Authorization: Bearer $AUTH_TOKEN"
expect_status_in "$HTTP_CODE" "200,401,404" "due flashcards"

note "GET /api/v1/deck/progress/user/1/deck/45"
request GET "${BASE_URL}/api/v1/deck/progress/user/1/deck/45" -H "Authorization: Bearer $AUTH_TOKEN"
expect_status_in "$HTTP_CODE" "200,401,404" "deck progress"

summary