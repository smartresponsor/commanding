#!/bin/bash
while true; do
  clear
  echo "=== Backup Menu ==="
  echo "1) composer.sh - !/usr/bin/env bash"
  echo "2) menu.sh - !/bin/bash"

  echo "3) Back to Main Menu"
  read -p "Choose an option: " choice
  case $choice in
    1) bash "$(dirname "$0")/composer.sh" ;;
    2) bash "$(dirname "$0")/menu.sh" ;;

    3) break ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac

  if [ $? -ne 0 ]; then
    exec bash
  fi
done
