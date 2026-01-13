#!/bin/bash
while true; do
  clear
  echo "=== Docker Menu ==="
  echo "1) docker.sh - !/usr/bin/env bash"
  echo "2) health.sh - !/usr/bin/env bash"
  echo "3) local_ci.sh - !/usr/bin/env bash"
  echo "4) menu.sh - !/bin/bash"

  echo "5) Back to Main Menu"
  read -p "Choose an option: " choice
  case $choice in
    1) bash "$(dirname "$0")/docker.sh" ;;
    2) bash "$(dirname "$0")/health.sh" ;;
    3) bash "$(dirname "$0")/local_ci.sh" ;;
    4) bash "$(dirname "$0")/menu.sh" ;;

    5) break ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac

  if [ $? -ne 0 ]; then
    exec bash
  fi
done
