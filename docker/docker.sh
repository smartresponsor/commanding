#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

clear
printf '%s\n' 'Docker'
printf '%s\n' '------'
printf '%s\n' '1) Up: DB'
printf '%s\n' '2) Up: ALL'
printf '%s\n' '3) Down: ALL'
printf '%s\n' '4) Logs: DB'
printf '%s\n' '5) Reset DB (drop volumes)'
printf '%s\n' ' '
printf '%s\n' 'Space) Exit'

read -r -n 1 -s -p 'Choice: ' action
printf '\n'

case "$action" in
  1) bash "$DIR/tool/up.sh" db ;;
  2) bash "$DIR/tool/up.sh" all ;;
  3) bash "$DIR/tool/down.sh" all ;;
  4) bash "$DIR/tool/logs.sh" db ;;
  5) bash "$DIR/tool/reset-db.sh" ;;
  *) exit 0 ;;
esac
