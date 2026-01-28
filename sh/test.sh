#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="logs/action.log"
ERR_FILE="logs/error.log"
mkdir -p logs

ui_clear
ui_banner "Test"
echo "Tests Menu"
echo "----------"
echo "1) Unit tests"
echo "2) Integration tests"
echo "3) E2E tests"
echo "4) Full suite (all)"
echo "Space) Exit"

read -r -n 1 -s -p "Choice: " action
echo

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
EXIT_CODE=0

case $action in
  1) echo "[$timestamp] Running Unit tests" >> "$LOG_FILE"
     vendor/bin/phpunit --testsuite=unit 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  2) echo "[$timestamp] Running Integration tests" >> "$LOG_FILE"
     vendor/bin/phpunit --testsuite=integration 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  3) echo "[$timestamp] Running E2E tests" >> "$LOG_FILE"
     vendor/bin/phpunit --testsuite=e2e 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  4) echo "[$timestamp] Running Full suite" >> "$LOG_FILE"
     vendor/bin/phpunit 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  *) echo "[$timestamp] Exit from Test menu" >> "$LOG_FILE"
     exit 0 ;;
esac

echo "[$timestamp] Exit code: $EXIT_CODE" >> "$LOG_FILE"
exit $EXIT_CODE
