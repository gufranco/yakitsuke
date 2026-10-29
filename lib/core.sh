#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

YAKITSUKE_VERSION="1.3.0"

yk_version() {
  printf '%s %s\n' "${YK_PROG}" "${YAKITSUKE_VERSION}"
}

yk_info() {
  yk_say 8 "$*"
}

yk_wrap() {
  awk -v width="${YK_WIDTH}" -v indent="$1" '
    function pad(n,   s) {
      s = ""
      while (n-- > 0) { s = s " " }
      return s
    }
    length($0) <= width { print; next }
    {
      match($0, /^ */)
      n = split($0, word, " ")
      out = substr($0, 1, RLENGTH) word[1]
      for (i = 2; i <= n; i++) {
        if (length(out) + 1 + length(word[i]) > width) {
          print out
          out = pad(indent) word[i]
        } else {
          out = out " " word[i]
        }
      }
      print out
    }'
}

yk_terminal() {
  [ "${YAKITSUKE_TERMINAL:-}" = 1 ] || [ -t 1 ]
}

yk_say() {
  yk_sy_text="$2"
  if [ "${#yk_sy_text}" -le "${YK_WIDTH}" ] || ! yk_terminal; then
    printf '%s\n' "${yk_sy_text}"
    return 0
  fi
  printf '%s\n' "${yk_sy_text}" | yk_wrap "$1"
}

yk_warning() {
  yk_say 0 "${YK_PROG}: warning: $*" >&2
}

yk_error() {
  yk_say 0 "${YK_PROG}: $*" >&2
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
