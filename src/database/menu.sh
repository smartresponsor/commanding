#!/bin/bash
while true; do
  clear
  echo "=== Database Menu ==="
  echo "1) menu.sh - !/bin/bash"
  echo "2) migration.sh"

  echo "3) Back to Main Menu"
  read -p "Choose an option: " choice
  case $choice in
    1) bash "$(dirname "$0")/menu.sh" ;;
    2) bash "$(dirname "$0")/migration.sh" ;;

    3) break ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac

  if [ $? -ne 0 ]; then
    exec bash
  fi
done
