#!/bin/bash
while true; do
  clear
  echo "=== Tests Menu ==="
  echo "1) test.sh"

  echo "2) Back to Main Menu"
  read -p "Choose an option: " choice
  case $choice in
    1) bash "$(dirname "$0")/test.sh" ;;

    2) break ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac

  if [ $? -ne 0 ]; then
    exec bash
  fi
done
