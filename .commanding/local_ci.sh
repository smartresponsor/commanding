#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="logs/action.log"
ERR_FILE="logs/error.log"
mkdir -p logs

clear
printf '%s\n' "Local CI Runner"
printf '%s\n' "------------------------"
printf '%s\n' "1 PHPStan"
printf '%s\n' "2 Container lint"
printf '%s\n' "3 Schema validate"
printf '%s\n' "4 Twig/YAML lint"
printf '%s\n' "5 PHPUnit (all)"
printf '%s\n' "6 PHPUnit with coverage"
printf '%s\n' "Space Exit"

read -r -n 1 -s -p "Choice: " action
echo

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
EXIT_CODE=0

case $action in
  1) echo "[$timestamp] PHPStan" >> "$LOG_FILE"
     vendor/bin/phpstan analyse --memory-limit=1G 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  2) echo "[$timestamp] Container lint" >> "$LOG_FILE"
     php bin/console lint:container 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  3) echo "[$timestamp] Schema validate" >> "$LOG_FILE"
     php bin/console doctrine:schema:validate --skip-sync 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  4) echo "[$timestamp] Twig+YAML lint" >> "$LOG_FILE"
     php bin/console lint:twig templates/ 2>>"$ERR_FILE" || EXIT_CODE=$?
     php bin/console lint:yaml config/ 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  5) echo "[$timestamp] PHPUnit all" >> "$LOG_FILE"
     vendor/bin/phpunit 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  6) echo "[$timestamp] PHPUnit with coverage" >> "$LOG_FILE"
     vendor/bin/phpunit --coverage-text 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  *) echo "[$timestamp] Exit from Local CI menu" >> "$LOG_FILE"
     echo "Bye"; return 1 ;;
esac

echo "[$timestamp] Exit code: $EXIT_CODE" >> "$LOG_FILE"
exit $EXIT_CODE
