#!/usr/bin/env bash
# ============================================================================
# Folder + Tab service tests
# NOTE: the folder/tab service is NOT routed through the deployed gateway —
# set FOLDER_URL in .env (e.g. http://localhost:8080) to test it directly.
# ============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

section "FOLDER & TAB SERVICE — ${FOLDER_URL}"

do_login

# ---------- folders ----------
note "GET /api/v1/folders/featured/all (public)"
request GET "${FOLDER_URL}/api/v1/folders/featured/all"
expect_status_in "$HTTP_CODE" "200,404,502" "featured folders"

if [[ -n "$AUTH_TOKEN" ]]; then
  A=(-H "Authorization: Bearer $AUTH_TOKEN")

  note "GET /api/v1/folders/all (paginated)"
  request GET "${FOLDER_URL}/api/v1/folders/all?page=1&pageSize=10" -H "Authorization: Bearer $AUTH_TOKEN"
  expect_status "$HTTP_CODE" "200" "folders all"
  expect_key "$BODY" "pagination" "response has pagination"

  note "POST /api/v1/folders (create)"
  request POST "${FOLDER_URL}/api/v1/folders" -H "Authorization: Bearer $AUTH_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"title":"QA Folder '"$(date +%s)"'","description":"created by smoke tests","category":"WORK"}'
  expect_status "$HTTP_CODE" "201" "create folder"
  expect_key "$BODY" "folder" "response has folder"
  NEW_FOLDER_ID="$(printf '%s' "$BODY" | sed -n 's/.*"folder"[[:space:]]*:[[:space:]]*{[^}]*"id"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')"

  note "GET /api/v1/folders/search?query=QA"
  request GET "${FOLDER_URL}/api/v1/folders/search?query=QA" -H "Authorization: Bearer $AUTH_TOKEN"
  expect_status_in "$HTTP_CODE" "200,400" "search folders"

  if [[ -n "$NEW_FOLDER_ID" && "$NEW_FOLDER_ID" != "0" ]]; then
    note "GET /api/v1/folders/{id} (created folder)"
    request GET "${FOLDER_URL}/api/v1/folders/$NEW_FOLDER_ID" -H "Authorization: Bearer $AUTH_TOKEN"
    expect_status "$HTTP_CODE" "200" "get folder by id"

    note "DELETE /api/v1/folders/{id} (cleanup)"
    request DELETE "${FOLDER_URL}/api/v1/folders/$NEW_FOLDER_ID" -H "Authorization: Bearer $AUTH_TOKEN"
    expect_status "$HTTP_CODE" "200" "delete folder"
  else
    skip "folder by id + delete (could not parse created id)"
  fi
else
  skip "folder CRUD (login failed)"
fi

# ---------- tabs ----------
note "GET /api/v1/tabs (paginated, public)"
request GET "${FOLDER_URL}/api/v1/tabs?page=1&pageSize=10"
expect_status_in "$HTTP_CODE" "200,502" "tabs list"
[[ "$HTTP_CODE" == "200" ]] && expect_key "$BODY" "pagination" "tabs has pagination"

note "GET /api/v1/tabs/{id}"
TAB_ID="${TEST_TAB_ID:-1}"
request GET "${FOLDER_URL}/api/v1/tabs/$TAB_ID"
expect_status_in "$HTTP_CODE" "200,404,502" "get tab by id"
[[ "$HTTP_CODE" == "200" ]] && expect_key "$BODY" "is_saved" "tab has is_saved"

if [[ -n "$AUTH_TOKEN" ]]; then
  A=(-H "Authorization: Bearer $AUTH_TOKEN")

  note "POST /api/v1/tabs (create)"
  request POST "${FOLDER_URL}/api/v1/tabs" "${A[@]}" \
    -H 'Content-Type: application/json' \
    -d "{\"title\":\"QA Tab $(date +%s)\",\"url\":\"https://example.com\",\"description\":\"smoke test\",\"tags\":[\"qa\"]}"
  expect_status "$HTTP_CODE" "201" "create tab"
  NEW_TAB_ID="$(printf '%s' "$BODY" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)"

  if [[ -n "$NEW_TAB_ID" && "$NEW_TAB_ID" != "0" ]]; then
    note "POST /api/v1/tabs/{id}/save"
    request POST "${FOLDER_URL}/api/v1/tabs/$NEW_TAB_ID/save" "${A[@]}"
    expect_status "$HTTP_CODE" "200" "save tab"

    note "GET /api/v1/tabs/saved"
    request GET "${FOLDER_URL}/api/v1/tabs/saved" "${A[@]}"
    expect_status "$HTTP_CODE" "200" "saved tabs list"

    note "GET /api/v1/tabs/recent"
    request GET "${FOLDER_URL}/api/v1/tabs/recent" "${A[@]}"
    expect_status "$HTTP_CODE" "200" "recent tabs list"

    note "DELETE /api/v1/tabs/{id}/unsave"
    request DELETE "${FOLDER_URL}/api/v1/tabs/$NEW_TAB_ID/unsave" "${A[@]}"
    expect_status "$HTTP_CODE" "200" "unsave tab"

    note "DELETE /api/v1/tabs/{id} (cleanup)"
    request DELETE "${FOLDER_URL}/api/v1/tabs/$NEW_TAB_ID" "${A[@]}"
    expect_status "$HTTP_CODE" "200" "delete tab"
  else
    skip "tab lifecycle (could not parse created id)"
  fi
else
  skip "tab lifecycle (login failed)"
fi

summary