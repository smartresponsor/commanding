#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

LOG_DIR="$COMMANDING_DIR/logs"
LOG_FILE="$LOG_DIR/actions.log"
ERR_FILE="$LOG_DIR/errors.log"
mkdir -p "$LOG_DIR"
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
EXIT_CODE=0

ui_clear
ui_banner "Cache"
echo "Symfony Cache Management"
echo "------------------------"
echo "1) Clear cache"
echo "2) Warmup cache"
echo "Space) Exit"

read -r -n 1 -s -p "Choice: " action
echo

case $action in
  1) echo "[$timestamp] Cache clear" >> "$LOG_FILE"
     php bin/console cache:clear 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  2) echo "[$timestamp] Cache warmup" >> "$LOG_FILE"
     php bin/console cache:warmup 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  *) echo "[$timestamp] Exit from Cache menu" >> "$LOG_FILE"
     return 0 2>/dev/null || exit 0 ;;
esac

echo "[$timestamp] Exit code: $EXIT_CODE" >> "$LOG_FILE"
exit $EXIT_CODE
