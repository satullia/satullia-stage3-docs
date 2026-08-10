# ============================================================================
# Satullia API test scripts — shared library
# ============================================================================
# Source: lib.sh
# Usage: source "$(dirname "$0")/lib.sh"
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# ---- config ----------------------------------------------------------------
CONF_FILE="${SCRIPT_DIR}/.env"
if [[ ! -f "$CONF_FILE" ]]; then
  echo "  ! missing $CONF_FILE — copy .env.example to .env and adjust" >&2
  exit 2
fi
set -a
# shellcheck disable=SC1090
source "$CONF_FILE"
set +a

BASE_URL="${BASE_URL:-https://api-satullia.danials.space}"
FILE_URL="${FILE_URL:-https://file-satullia.danials.space}"
FOLDER_URL="${FOLDER_URL:-${BASE_URL}}"
POST_URL="${POST_URL:-${BASE_URL}}"

AUTH_TOKEN="${AUTH_TOKEN:-}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"

# ---- colours ---------------------------------------------------------------
C_GREEN=$'\033[0;32m'; C_RED=$'\033[0;31m'; C_YELLOW=$'\033[1;33m'
C_CYAN=$'\033[0;36m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'

TS="$(date +%F_%H-%M-%S)"
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="${REPORT_DIR}/report_${TS}.log"

_pass=0; _fail=0; _skip=0

# ---- helpers ---------------------------------------------------------------
log()  { printf '%s\n' "$*" | tee -a "$REPORT_FILE"; }
note() { printf '  %s%s%s\n' "$C_CYAN" "$*" "$C_RESET" | tee -a "$REPORT_FILE"; }
ok()   { _pass=$((_pass+1)); printf '  %s✔ PASS%s  %s\n' "$C_GREEN" "$C_RESET" "$*" | tee -a "$REPORT_FILE"; }
skip() { _skip=$((_skip+1)); printf '  %s⏭ SKIP%s  %s\n' "$C_YELLOW" "$C_RESET" "$*" | tee -a "$REPORT_FILE"; }
fail() { _fail=$((_fail+1)); printf '  %s✘ FAIL%s  %s\n' "$C_RED" "$C_RESET" "$*" | tee -a "$REPORT_FILE"; }

section() {
  printf '\n%s==== %s ====%s\n' "$C_BOLD" "$1" "$C_RESET" | tee -a "$REPORT_FILE"
}

# expect_status <actual> <expected> <label>
expect_status() {
  if [[ "$1" == "$2" ]]; then ok "$3  (HTTP $1)"; else fail "$3  (got HTTP $1, want $2)"; fi
}

# expect_status_in <actual> <comma-separated codes> <label>
expect_status_in() {
  local a="$1" list="$2" label="$3"
  for c in ${list//,/ }; do [[ "$a" == "$c" ]] && { ok "$label  (HTTP $a)"; return 0; }; done
  fail "$label  (got HTTP $a, want one of $list)"
}

# expect_key <json> <key> <label>
expect_key() {
  if [[ "$1" == *"\"$2\""* ]]; then ok "$3"; else fail "$3  (key \"$2\" not in body: $(printf '%s' "$1" | head -c 160))"; fi
}

# expect_json <json> <expected-string> <label>
expect_json() {
  if [[ "$1" == *"$2"* ]]; then ok "$3"; else fail "$3  (body: $(printf '%s' "$1" | head -c 160))"; fi
}

# request <method> <url> [curl args...]  -> sets HTTP_CODE and BODY
request() {
  local method="$1" url="$2"; shift 2
  local tmp="$(mktemp)"
  HTTP_CODE="$(curl -s -m 20 -o "$tmp" -w '%{http_code}' -X "$method" "$url" "$@")"
  BODY="$(cat "$tmp")"
  rm -f "$tmp"
}

# login helper -> sets AUTH_TOKEN and REFRESH_TOKEN (uses TEST_EMAIL / TEST_PASSWORD)
do_login() {
  local body
  body="$(curl -s -m 20 -X POST "${BASE_URL}/api/v1/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${TEST_EMAIL:-test@gmail.com}\",\"password\":\"${TEST_PASSWORD:-passWORD@@22}\"}")"
  AUTH_TOKEN="$(printf '%s' "$body" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  REFRESH_TOKEN="$(printf '%s' "$body" | sed -n 's/.*"refresh_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
}

# empty body + auth header, used when auth middleware returns plain-text 401
AUTH_H=( -H "Authorization: Bearer ${AUTH_TOKEN}" )
AUTH_A_H=( -H "Authorization: Bearer ${ADMIN_TOKEN:-${AUTH_TOKEN}}" )

summary() {
  printf '\n%s==== SUMMARY ====%s\n' "$C_BOLD" "$C_RESET" | tee -a "$REPORT_FILE"
  printf '  %sTotal:%s %d   %sPassed:%s %d   %sFailed:%s %d   %sSkipped:%s %d\n' \
    "$C_CYAN" "$C_RESET" "$((_pass+_fail+_skip))" \
    "$C_GREEN" "$C_RESET" "$_pass" \
    "$C_RED" "$C_RESET" "$_fail" \
    "$C_YELLOW" "$C_RESET" "$_skip" | tee -a "$REPORT_FILE"
  printf '  report: %s\n' "$REPORT_FILE"
  [[ "$_fail" -eq 0 ]]
}