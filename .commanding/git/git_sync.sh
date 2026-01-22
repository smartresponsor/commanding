#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

clear
echo "Git Sync"
echo "---------"
echo "1) Pull"
echo "2) Pull with rebase"
echo "3) Push"
echo "Space/Enter) Back"
echo

read -r -n 1 -s -p "Choice: " action || true
echo

case "${action:-}" in
  1) exec git pull origin master ;;
  2) exec git pull --rebase origin master ;;
  3) exec git push origin master ;;
  ""|" "|$'\n'|$'\r') exit 0 ;;
  *) echo "Back"; exit 0 ;;
esac
