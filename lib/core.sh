#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

YAKITSUKE_VERSION="1.7.0"

yk_version() {
  printf '%s %s\n' "${YK_PROG}" "${YAKITSUKE_VERSION}"
}

yk_info() {
  [ "${YK_JSON}" = no ] || return 0
  yk_say "$*"
}

yk_json_string() {
  printf '%s' "$1" | awk '
    BEGIN { for (i = 1; i < 32; i++) code[sprintf("%c", i)] = sprintf("\\u%04x", i) }
    function escape(s,   r, c, i) {
      r = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\") r = r "\\\\"
        else if (c == "\"") r = r "\\\""
        else if (c in code) r = r code[c]
        else r = r c
      }
      return r
    }
    { out = out (NR > 1 ? "\\n" : "") escape($0) }
    END { printf "\"%s\"", out }'
}

yk_say() {
  printf '%s\n' "$1"
}

yk_warning() {
  if yk_ui_err; then
    yk_ui_log WARN "$*"
    return 0
  fi
  yk_say "${YK_PROG}: warning: $*" >&2
}

yk_error() {
  if yk_ui_err; then
    yk_ui_log ERROR "$*"
    return 0
  fi
  yk_say "${YK_PROG}: $*" >&2
}

yk_detail() {
  [ -s "$1" ] || return 0
  tail -n 20 "$1" | while IFS= read -r yk_dt_line; do
    yk_error "  ${yk_dt_line}"
  done
  return 0
}

yk_cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

yk_is_uint() {
  case "$1" in
  '' | *[!0-9]*) return 1 ;;
  *) return 0 ;;
  esac
}

yk_is_number() {
  case "$1" in
  '' | *[!0-9.+-]* | *.*.* | ?*[+-]* | [+-] | . | [+-].) return 1 ;;
  *) return 0 ;;
  esac
}

yk_calc() {
  awk "BEGIN { printf \"%.3f\\n\", $1 }"
}

yk_greater() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 > b + 0) }'
}

yk_clock() {
  awk -v d="$1" 'BEGIN { printf "%d:%02d:%02d\n", d / 3600, (d % 3600) / 60, d % 60 }'
}

yk_absolute_path() {
  yk_ap_dir="$(dirname -- "$1")"
  yk_ap_base="$(basename -- "$1")"
  yk_ap_dir="$(cd -- "${yk_ap_dir}" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s\n' "${yk_ap_dir%/}" "${yk_ap_base}"
}

yk_iso_label() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9_' '_' | cut -c1-32
}

yk_file_bytes() {
  yk_fb_bytes="$(wc -c <"$1")"
  printf '%s\n' "${yk_fb_bytes}" | tr -d '[:space:]'
  printf '\n'
}

yk_lines() {
  printf '%s\n' "$1" | awk 'NF { n++ } END { print n + 0 }'
}
