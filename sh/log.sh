#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

#!/usr/bin/env bash
set -euo pipefail

ui_clear
ui_banner "Log"
echo "Logs Menu"
echo "---------"
echo "1) Symfony server logs"
echo "2) Docker logs"
echo "Space) Exit"

read -r -n 1 -s -p "Choice: " action
echo

case $action in
  1) exec symfony server:log ;;
  2) exec docker compose logs -f ;;
  *) exit 0 ;;
esac
