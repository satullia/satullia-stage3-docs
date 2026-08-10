#!/usr/bin/env bash
# ============================================================================
# Run all Satullia API smoke tests
# Usage: ./run_all.sh [service...]
#   examples:
#     ./run_all.sh                # everything
#     ./run_all.sh deck auth      # only deck + auth
#     ./run_all.sh 05 08          # only deck + file tests
# ============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f .env ]]; then
  echo "! missing .env — copy .env.example to .env and adjust the URLs/tokens"
  exit 2
fi

TESTS=()

if [[ $# -gt 0 ]]; then
  for arg in "$@"; do
    case "$arg" in
      gateway|09) TESTS+=("09-gateway.test.sh") ;;
      auth|01)    TESTS+=("01-auth.test.sh") ;;
      profile|02) TESTS+=("02-profile.test.sh") ;;
      access|03)  TESTS+=("03-access-control.test.sh") ;;
      folder|tab|folders|04) TESTS+=("04-folder-tab.test.sh") ;;
      deck|05)    TESTS+=("05-deck.test.sh") ;;
      post|06)    TESTS+=("06-post.test.sh") ;;
      version|app-version|07) TESTS+=("07-app-version.test.sh") ;;
      file|08)    TESTS+=("08-file.test.sh") ;;
      *) echo "! unknown test: $arg (options: gateway auth profile access folder deck post version file)" >&2; exit 2 ;;
    esac
  done
else
  TESTS=(09-gateway 01-auth 02-profile 03-access-control 04-folder-tab 05-deck 06-post 07-app-version 08-file)
  TESTS=("${TESTS[@]/%/.test.sh}")
fi

declare -a RESULTS=()
for t in "${TESTS[@]}"; do
  [[ -f "$t" ]] || { echo "! missing $t"; continue; }
  echo ""
  echo "████ Running: $t ████"
  if bash "$t"; then RESULTS+=("✔  $t"); else RESULTS+=("✘  $t"); fi
done

echo ""
echo "████ RESULTS ████"
printf '  %s\n' "${RESULTS[@]}"
fails=$(printf '%s\n' "${RESULTS[@]}" | grep -c '^✘' || true)
[[ "$fails" -eq 0 ]]