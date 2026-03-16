#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=./_lib.sh
source "$DIR/tool/_lib.sh"

stack="${1:-db}"
repo_root="$(find_repo_root)"
export_defaults "$repo_root"

cmd="$(compose_cmd)"

run_stack() {
  local s="$1"
  mapfile -t files < <(collect_files "$s" "$DIR" "$repo_root")

  local args=()
  for f in "${files[@]}"; do
    args+=( -f "$f" )
  done

  $cmd "${args[@]}" up -d --remove-orphans
}

if [ "$stack" = "all" ]; then
  run_stack db
  run_stack cache
  run_stack mq
  run_stack object
  run_stack obs
  exit 0
fi

run_stack "$stack"
