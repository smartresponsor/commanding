#!/bin/sh
# dot.sh
# Dot-run scanner + runner (ps/sh) with fallback + logging.
# Entry: dot_folder "."  (auto-called at the bottom if executed directly)

dot_folder() {
  ROOT="${1:-.}"

  # Accept list (whitelist): ONLY these dot-folders will be processed
  DOT_ACCEPT="
.smoke
.gate
.release
.tool
"

  dot_have_cmd() { command -v "$1" >/dev/null 2>&1; }

  dot_is_windows() {
    [ "${OS:-}" = "Windows_NT" ] && return 0
    uname_s="$(uname 2>/dev/null || echo "")"
    echo "$uname_s" | grep -qiE 'mingw|msys|cygwin' && return 0
    return 1
  }

  dot_ps_runner() {
    if dot_have_cmd pwsh; then echo "pwsh"; return 0; fi
    if dot_have_cmd powershell; then echo "powershell"; return 0; fi
    if dot_have_cmd powershell.exe; then echo "powershell.exe"; return 0; fi
    return 1
  }

  dot_is_accepted_dir() {
    _base="$(basename "$1")"
    for _a in $DOT_ACCEPT; do
      [ "$_base" = "$_a" ] && return 0
    done
    return 1
  }

  dot_now() {
    date +"%Y%m%d-%H%M%S" 2>/dev/null || echo "time-unknown"
  }

  dot_log_init() {
    [ -n "${DOT_LOG:-}" ] && return 0
    ts="$(dot_now)"

    if [ -d "./.commanding" ]; then
      mkdir -p "./.commanding/log" 2>/dev/null || true
      DOT_LOG="./.commanding/log/dot-$ts.log"
    else
      DOT_LOG="/tmp/dot-$ts.log"
    fi

    : > "$DOT_LOG" 2>/dev/null || DOT_LOG="/tmp/dot-$ts.log"
    export DOT_LOG
  }

  dot_log() {
    dot_log_init
    printf "%s\n" "$*" >> "$DOT_LOG"
  }

  dot_detect_runner_for_runfile() {
    f="$1"
    first="$(head -n 1 "$f" 2>/dev/null || true)"

    echo "$first" | grep -qiE 'pwsh|powershell' && { echo "ps"; return 0; }
    echo "$first" | grep -qiE 'sh|bash' && { echo "sh"; return 0; }

    if dot_is_windows && dot_ps_runner >/dev/null 2>&1; then
      echo "ps"; return 0
    fi
    echo "sh"
  }

  dot_pick_candidates() {
    # output lines: "<runner>\t<file>"
    d="$1"

    ps=""
    sh=""
    any=""

    [ -f "$d/run.ps1" ] && ps="$d/run.ps1"
    [ -f "$d/run.sh" ]  && sh="$d/run.sh"
    [ -f "$d/run" ]     && any="$d/run"

    # explicit pair: prefer by platform
    if [ -n "$ps" ] && [ -n "$sh" ]; then
      if dot_is_windows && dot_ps_runner >/dev/null 2>&1; then
        printf "ps\t%s\n" "$ps"
        printf "sh\t%s\n" "$sh"
        return 0
      fi
      printf "sh\t%s\n" "$sh"
      printf "ps\t%s\n" "$ps"
      return 0
    fi

    # single explicit
    [ -n "$ps" ] && printf "ps\t%s\n" "$ps"
    [ -n "$sh" ] && printf "sh\t%s\n" "$sh"

    # generic run => detect
    if [ -n "$any" ]; then
      r="$(dot_detect_runner_for_runfile "$any")"
      printf "%s\t%s\n" "$r" "$any"
    fi

    return 0
  }

  dot_exec_one_logged() {
    runner="$1"
    file="$2"
    dir="$(dirname "$file")"
    base="$(basename "$file")"

    dot_log_init

    dot_log "============================================================"
    dot_log "START  runner=$runner  file=$file"
    dot_log "CWD    $dir"
    dot_log "TIME   $(dot_now)"
    dot_log "------------------------------------------------------------"

    tmp_out="$(mktemp)"
    trap 'rm -f "$tmp_out"' INT TERM HUP

    (
      cd "$dir" || exit 1

      if [ "$runner" = "ps" ]; then
        psbin="$(dot_ps_runner 2>/dev/null || true)"
        [ -n "$psbin" ] || { echo "PowerShell runner not found"; exit 127; }
        "$psbin" -NoProfile -ExecutionPolicy Bypass -File "./$base"
      else
        if [ -x "./$base" ]; then
          "./$base"
        else
          sh "./$base"
        fi
      fi
    ) >"$tmp_out" 2>&1

    rc=$?

    # show live output
    cat "$tmp_out"
    # append to log
    cat "$tmp_out" >> "$DOT_LOG"

    dot_log "------------------------------------------------------------"
    dot_log "END    runner=$runner  rc=$rc"
    dot_log "TIME   $(dot_now)"
    dot_log "============================================================"
    dot_log ""

    rm -f "$tmp_out"
    trap - INT TERM HUP

    return "$rc"
  }

  dot_exec_with_fallback() {
    d="$1"

    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' INT TERM HUP
    dot_pick_candidates "$d" > "$tmp"

    [ -s "$tmp" ] || { rm -f "$tmp"; trap - INT TERM HUP; return 0; }

    primary_runner=""
    primary_file=""
    fallback_runner=""
    fallback_file=""

    i=0
    while IFS="$(printf '\t')" read -r runner file; do
      [ -n "$runner" ] || continue
      [ -n "$file" ] || continue
      i=$((i + 1))
      if [ "$i" -eq 1 ]; then
        primary_runner="$runner"
        primary_file="$file"
      elif [ "$i" -eq 2 ]; then
        fallback_runner="$runner"
        fallback_file="$file"
        break
      fi
    done < "$tmp"

    rm -f "$tmp"
    trap - INT TERM HUP

    dot_log_init
    dot_log "DOT-FOLDER: $d"
    dot_log "PRIMARY : $primary_runner -> $primary_file"
    [ -n "$fallback_file" ] && dot_log "FALLBACK: $fallback_runner -> $fallback_file"
    dot_log ""

    echo ""
    echo "TRY(primary): $primary_runner -> $primary_file"
    echo ""

    if dot_exec_one_logged "$primary_runner" "$primary_file"; then
      echo ""
      echo "OK(primary): $primary_runner"
      echo "LOG: $DOT_LOG"
      echo ""
      return 0
    fi
    rc1=$?

    if [ -n "$fallback_file" ] && [ "$fallback_file" != "$primary_file" ]; then
      echo ""
      echo "TRY(fallback): $fallback_runner -> $fallback_file"
      echo ""

      if dot_exec_one_logged "$fallback_runner" "$fallback_file"; then
        echo ""
        echo "OK(fallback): $fallback_runner (primary rc=$rc1)"
        echo "LOG: $DOT_LOG"
        echo ""
        return 0
      fi
      rc2=$?
    else
      rc2=0
    fi

    echo ""
    echo "FAILED: primary rc=$rc1, fallback rc=$rc2"
    echo "LOG: $DOT_LOG"
    echo ""

    if [ -n "$fallback_file" ]; then
      return "$rc2"
    fi
    return "$rc1"
  }

  dot_scan() {
    find "$ROOT" -type d -name '.*' -print 2>/dev/null || true
  }

  dot_has_any_run() {
    d="$1"
    [ -f "$d/run.ps1" ] || [ -f "$d/run.sh" ] || [ -f "$d/run" ]
  }

  # --- BOOT: scan and execute (non-interactive) ----------------------------

  echo ""
  echo "Dot boot: scanning $ROOT ..."
  echo ""

  dot_log_init
  dot_log "DOT root=$ROOT time=$(dot_now)"

  dot_scan | while IFS= read -r d; do
    [ -n "$d" ] || continue
    dot_is_accepted_dir "$d" || continue
    dot_has_any_run "$d" || continue

    echo "==> $d"
    dot_exec_with_fallback "$d" || true
  done

  # If nothing matched => print DOT_ACCEPT
  match_count="$(find "$ROOT" -type d -name '.*' 2>/dev/null \
    | while IFS= read -r d; do
        [ -n "$d" ] || continue
        dot_is_accepted_dir "$d" || continue
        dot_has_any_run "$d" || continue
        echo "1"
      done | wc -l | tr -d ' ')"

  if [ "${match_count:-0}" -eq 0 ]; then
    echo ""
    echo "Nothing found."
    echo "DOT_ACCEPT:"
    printf "%s\n" "$DOT_ACCEPT" | sed 's/^ *//g' | sed '/^$/d' | while IFS= read -r x; do
      printf "  - %s\n" "$x"
    done
    echo ""
  fi
}

# Run if executed directly (Commanding runs this file as a script)
dot_folder "${1:-.}"
