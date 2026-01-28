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
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
EXIT_CODE=0

ui_clear
ui_banner "Composer"
echo "Composer Menu"
echo "-------------"
echo "1) Install"
echo "2) Update"
echo "3) Dump autoload"
echo "Space) Exit"

read -r -n 1 -s -p "Choice: " action
echo

case $action in
  1) echo "[$timestamp] Composer install" >> "$LOG_FILE"
     composer install 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  2) echo "[$timestamp] Composer update" >> "$LOG_FILE"
     composer update 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  3) echo "[$timestamp] Composer dump-autoload" >> "$LOG_FILE"
     composer dump-autoload 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  *) echo "[$timestamp] Exit from Composer menu" >> "$LOG_FILE"
     exit 0 ;;
esac

echo "[$timestamp] Exit code: $EXIT_CODE" >> "$LOG_FILE"
exit $EXIT_CODE
