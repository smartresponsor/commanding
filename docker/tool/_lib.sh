#!/usr/bin/env bash
set -euo pipefail

script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

find_repo_root() {
  local d
  d="$(cd -- "$(script_dir)/.." && pwd)" # docker/
  while [ "$d" != "/" ]; do
    if [ "$(basename -- "$d")" = ".commanding" ]; then
      cd -- "$(dirname -- "$d")" && pwd
      return 0
    fi
    d="$(dirname -- "$d")"
  done
  cd -- "$(script_dir)/../.." && pwd
}

sanitize_project() {
  local s="$1"
  s="${s,,}"
  s="$(printf '%s' "$s" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  if [ -z "$s" ]; then
    s="sr"
  fi
  printf '%s' "$s"
}

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    printf '%s' 'docker compose'
    return 0
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    printf '%s' 'docker-compose'
    return 0
  fi
  printf '%s' 'docker compose'
}

collect_files() {
  local stack="$1"
  local docker_dir="$2"
  local repo_root="$3"

  local base="$docker_dir/compose/compose-$stack.yml"
  if [ ! -f "$base" ]; then
    printf '%s\n' "Missing base compose: $base" >&2
    return 2
  fi

  printf '%s\n' "$base"

  local ov="$repo_root/deploy/docker/compose-$stack.override.yml"
  if [ -f "$ov" ]; then
    printf '%s\n' "$ov"
  fi

  local ov_all="$repo_root/deploy/docker/compose.override.yml"
  if [ -f "$ov_all" ]; then
    printf '%s\n' "$ov_all"
  fi
}

export_defaults() {
  local repo_root="$1"
  local base
  base="$(basename -- "$repo_root")"
  export SR_COMPOSE_PROJECT="${SR_COMPOSE_PROJECT:-$(sanitize_project "$base")}" 
  export COMPOSE_PROJECT_NAME="$SR_COMPOSE_PROJECT"
}
