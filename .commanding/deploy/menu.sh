#!/bin/bash
while true; do
  clear
  echo "=== Deploy Menu ==="
  echo "1) command.sh"
  echo "2) deploy.sh - !/usr/bin/env bash"
  echo "3) logs.sh - !/usr/bin/env bash"
  echo "4) menu.sh - !/bin/bash"
  echo "5) notificationTest.sh - !/bin/bash"
  echo "6) server.sh"
  echo "7) service.sh"

  echo "8) Back to Main Menu"
  read -p "Choose an option: " choice
  case $choice in
    1) bash "$(dirname "$0")/command.sh" ;;
    2) bash "$(dirname "$0")/deploy.sh" ;;
    3) bash "$(dirname "$0")/logs.sh" ;;
    4) bash "$(dirname "$0")/menu.sh" ;;
    5) bash "$(dirname "$0")/notificationTest.sh" ;;
    6) bash "$(dirname "$0")/server.sh" ;;
    7) bash "$(dirname "$0")/service.sh" ;;

    8) break ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac

  if [ $? -ne 0 ]; then
    exec bash
  fi
done
