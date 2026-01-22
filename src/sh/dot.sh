#!/bin/sh
# dot.sh
# Scan accepted dot-folders -> functional verb folders -> run entrypoint (run|run.sh|run.ps1)
# Label: "<dot>/<verb>"  (example: .smoke/check)
# Executes run with ps/sh detection + fallback + logging.

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
    if dot_have_cmd pwsh; then echo " pwsh"; return 0; fi
    if dot_have_cmd powershell; then echo " powershell"; return 0; fi
    if dot_have_cmd powershell.exe; then echo " powershell.exe"; return 0; fi
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

  dot_rel() {
    p="$1"
    case "$p" in
      "$ROOT"/*) printf "%s\n" "${p#"$ROOT"/}" ;;
      "./"*) printf "%s\n" "${p#./}" ;;
      *) printf "%s\n" "$p" ;;
    esac
  }

  dot_detect_runner_for_file() {
    f="$1"

    case "$f" in
      *.ps1) echo " ps"; return 0 ;;
      *.sh)  echo " sh"; return 0 ;;
    esac

    first="$(head -n 1 "$f" 2>/dev/null || true)"
    echo "  $first" | grep -qiE 'pwsh|powershell' && { echo "ps"; return 0; }
    echo "  $first" | grep -qiE 'sh|bash' && { echo "sh"; return 0; }

    if dot_is_windows && dot_ps_runner >/dev/null 2>&1; then
      echo "ps"; return 0
    fi
    echo "sh"
  }

  dot_find_run_in_verb_dir() {
    # input: verb dir path (e.g. .smoke/check)
    # output: absolute/relative path to run file, or empty
    vd="$1"

    [ -f "$vd/run" ]     && { printf "%s\n" "$vd/run"; return 0; }
    [ -f "$vd/run.sh" ]  && { printf "%s\n" "$vd/run.sh"; return 0; }
    [ -f "$vd/run.ps1" ] && { printf "%s\n" "$vd/run.ps1"; return 0; }

    return 1
  }

  dot_exec_one_logged() {
    label="$1"
    runner="$2"
    file="$3"

    dir="$(dirname "$file")"
    base="$(basename "$file")"

    dot_log_init

    dot_log "============================================================"
    dot_log "LABEL  $label"
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
        [ -n "$psbin" ] || { echo " PowerShell runner not found"; exit 127; }
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

    cat "$tmp_out"
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
    label="$1"
    file="$2"

    primary="$(dot_detect_runner_for_file "$file")"
    fallback=""

    if [ "$primary" = "ps" ]; then fallback="sh"; else fallback="ps"; fi

    echo ""
    echo "  ==> $label"
    echo "  TRY(primary): $primary -> $(dot_rel "$file")"
    echo ""

    if dot_exec_one_logged "$label" "$primary" "$file"; then
      echo ""
      echo "  OK(primary): $primary"
      echo "  LOG: $DOT_LOG"
      echo ""
      return 0
    fi
    rc1=$?

    # fallback only if PS exists when needed
    if [ "$fallback" = "ps" ]; then
      dot_ps_runner >/dev/null 2>&1 || {
        echo ""
        echo "  FAILED: primary rc=$rc1, fallback skipped (no PowerShell)"
        echo "  LOG: $DOT_LOG"
        echo ""
        return "$rc1"
      }
    fi

    echo ""
    echo "   TRY(fallback): $fallback -> $(dot_rel "$file")"
    echo ""

    if dot_exec_one_logged "$label" "$fallback" "$file"; then
      echo ""
      echo "  OK(fallback): $fallback (primary rc=$rc1)"
      echo "  LOG: $DOT_LOG"
      echo ""
      return 0
    fi
    rc2=$?

    echo ""
    echo "  FAILED: primary rc=$rc1, fallback rc=$rc2"
    echo "  LOG: $DOT_LOG"
    echo ""

    return "$rc2"
  }

  dot_scan_accept_dirs() {
    find "$ROOT" -type d -name '.*' -print 2>/dev/null \
      | while IFS= read -r d; do
          [ -n "$d" ] || continue
          dot_is_accepted_dir "$d" || continue
          echo "$d"
        done
  }

  dot_scan_verb_dirs() {
    # input: accepted dot dir
    ad="$1"
    # functional verbs = immediate subdirs only (level 2 from root dot-folder)
    find "$ad" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null || true
  }

  # --- BOOT ----------------------------------------------------------------
  clear
  echo ""
  echo "  Dot boot: scanning $ROOT ..."
  echo ""

  dot_log_init
  dot_log " DOT root=$ROOT time=$(dot_now)"
  dot_log " DOT_ACCEPT=$(printf "%s" "$DOT_ACCEPT" | tr '\n' ' ' )"
  dot_log ""

  tmp_found="$(mktemp)"
  trap 'rm -f "$tmp_found"' EXIT INT TERM HUP
  : > "$tmp_found"

  dot_scan_accept_dirs | while IFS= read -r ad; do
    [ -n "$ad" ] || continue

    dot_scan_verb_dirs "$ad" | while IFS= read -r vd; do
      [ -n "$vd" ] || continue

      runfile="$(dot_find_run_in_verb_dir "$vd" 2>/dev/null || true)"
      [ -n "$runfile" ] || continue

      dot_name="$(basename "$ad")"
      verb_name="$(basename "$vd")"
      label="${dot_name}/${verb_name}"

      printf "    %s\t%s\n" "$label" "$runfile" >> "$tmp_found"
    done
  done

  if [ -s "$tmp_found" ]; then
    sort -u "$tmp_found" | while IFS="$(printf '\t')" read -r label runfile; do
      [ -n "$label" ] || continue
      [ -n "$runfile" ] || continue
      dot_exec_with_fallback "$label" "$runfile" || true
    done
    return 0
  fi

  echo ""
  echo "  Nothing found."
  echo "  DOT_ACCEPT:"
  printf "  %s\n" "$DOT_ACCEPT" | sed 's/^ *//g' | sed '/^$/d' | while IFS= read -r x; do
  printf "  - %s\n" "$x"
  done
  echo ""
  echo "  Expected structure:"
  echo "  .gate/check/run.sh"
  echo "  .release/install/run.ps1"
  echo "  .smoke/deploy/run"
  echo ""
}

# Run if executed directly (Commanding runs this file as a script)
dot_folder "${1:-.}"
