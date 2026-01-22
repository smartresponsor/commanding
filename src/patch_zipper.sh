#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

ZIP_NAME="patch-$(date +%Y-%m-%d-%H-%M-%S).zip"

if [ $# -eq 0 ]; then
  echo "No files provided."
  exit 1
fi

zip "$ZIP_NAME" "$@"
echo "Created archive: $ZIP_NAME"
