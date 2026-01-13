#!/bin/bash
while true; do
  clear
  echo "=== Misc Menu ==="
  echo "1) cache.sh - !/usr/bin/env bash"
  echo "2) fixture.sh"
  echo "3) history.sh - !/usr/bin/env bash"
  echo "4) menu.sh - !/bin/bash"
  echo "5) patch_ziper.sh - !/bin/bash"
  echo "6) route.sh"
  echo "7) schema.sh"
  echo "8) zipper.sh - !/usr/bin/env bash"

  echo "9) Back to Main Menu"
  read -p "Choose an option: " choice
  case $choice in
    1) bash "$(dirname "$0")/cache.sh" ;;
    2) bash "$(dirname "$0")/fixture.sh" ;;
    3) bash "$(dirname "$0")/history.sh" ;;
    4) bash "$(dirname "$0")/menu.sh" ;;
    5) bash "$(dirname "$0")/patch_ziper.sh" ;;
    6) bash "$(dirname "$0")/route.sh" ;;
    7) bash "$(dirname "$0")/schema.sh" ;;
    8) bash "$(dirname "$0")/zipper.sh" ;;

    9) break ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac

  if [ $? -ne 0 ]; then
    exec bash
  fi
done
