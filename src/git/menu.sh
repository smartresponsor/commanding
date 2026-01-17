#!/bin/bash
while true; do
  clear
  echo "=== Git Menu ==="
  echo "1) git_diff.sh - !/usr/bin/env bash"
  echo "2) git_status.sh - !/usr/bin/env bash"
  echo "3) git_sync.sh - !/usr/bin/env bash"
  echo "4) menu.sh - !/bin/bash"

  echo "5) Back to Main Menu"
  read -p "Choose an option: " choice
  case $choice in
    1) bash "$(dirname "$0")/git_diff.sh" ;;
    2) bash "$(dirname "$0")/git_status.sh" ;;
    3) bash "$(dirname "$0")/git_sync.sh" ;;
    4) bash "$(dirname "$0")/menu.sh" ;;

    5) break ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac

  if [ $? -ne 0 ]; then
    exec bash
  fi
done
