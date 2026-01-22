#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="logs/action.log"
ERR_FILE="logs/error.log"
mkdir -p logs
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
EXIT_CODE=0

clear
echo "Docker Menu"
echo "-----------"
echo "1) Up"
echo "2) Down"
echo "3) Logs"
echo "Space) Exit"

read -r -n 1 -s -p "Choice: " action
echo

case $action in
  1) echo "[$timestamp] Docker up" >> "$LOG_FILE"
     docker-compose up -d 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  2) echo "[$timestamp] Docker down" >> "$LOG_FILE"
     docker-compose down 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  3) echo "[$timestamp] Docker logs" >> "$LOG_FILE"
     docker-compose logs -f 2>>"$ERR_FILE" || EXIT_CODE=$? ;;
  *) echo "[$timestamp] Exit from Docker menu" >> "$LOG_FILE"
     echo "Bye"; return 1 ;;
esac

echo "[$timestamp] Exit code: $EXIT_CODE" >> "$LOG_FILE"
exit $EXIT_CODE
