#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=./_lib.sh
source "$DIR/tool/_lib.sh"

repo_root="$(find_repo_root)"
export_defaults "$repo_root"

cmd="$(compose_cmd)"

mapfile -t files < <(collect_files db "$DIR" "$repo_root")
args=()
for f in "${files[@]}"; do
  args+=( -f "$f" )
 done

$cmd "${args[@]}" down -v --remove-orphans
$cmd "${args[@]}" up -d --remove-orphans
