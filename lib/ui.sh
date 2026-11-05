#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

# shellcheck disable=SC2034
yk_ui_set() {
  YK_UI_ACCENT="$1"
  YK_UI_OK="$2"
  YK_UI_WARN="$3"
  YK_UI_ERR="$4"
  YK_UI_MUTED="$5"
  YK_UI_TEXT="$6"
  YK_UI_SURFACE="$7"
  YK_UI_HELP="$8"
}

yk_ui_palette() {
  case "$1" in
  kodougu) yk_ui_set "#F25D94" "#50FA7B" "#FFB86C" "#FF5555" "#6C7086" "#CDD6F4" "#313244" pink ;;
  catppuccin-mocha) yk_ui_set "#CBA6F7" "#A6E3A1" "#FAB387" "#F38BA8" "#6C7086" "#CDD6F4" "#313244" dark ;;
  catppuccin-latte) yk_ui_set "#8839EF" "#40A02B" "#FE640B" "#D20F39" "#8C8FA1" "#4C4F69" "#CCD0DA" light ;;
  dracula) yk_ui_set "#BD93F9" "#50FA7B" "#FFB86C" "#FF5555" "#6272A4" "#F8F8F2" "#44475A" dracula ;;
  nord) yk_ui_set "#88C0D0" "#A3BE8C" "#EBCB8B" "#BF616A" "#4C566A" "#D8DEE9" "#3B4252" dark ;;
  gruvbox) yk_ui_set "#FE8019" "#B8BB26" "#FABD2F" "#FB4934" "#928374" "#EBDBB2" "#3C3836" dark ;;
  tokyo-night) yk_ui_set "#7AA2F7" "#9ECE6A" "#E0AF68" "#F7768E" "#565F89" "#C0CAF5" "#292E42" tokyo-night ;;
  mono) yk_ui_set "" "" "" "" "" "" "" ascii ;;
  *) return 1 ;;
  esac
}

yk_ui_is_colour() {
  case "$1" in
  \#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) return 0 ;;
  *) return 1 ;;
  esac
}

# shellcheck disable=SC2034
yk_ui_setup() {
  if ! yk_ui_palette "${YK_THEME}"; then
    yk_ui_palette mono
    YK_UI_PROBLEM="--theme must be one of ${YK_UI_THEMES}, got: ${YK_THEME}"
    return 1
  fi
  if [ -n "${YK_ACCENT}" ] && ! yk_ui_is_colour "${YK_ACCENT}"; then
    YK_UI_PROBLEM="KODOUGU_ACCENT must be a colour such as #CBA6F7, got: ${YK_ACCENT}"
    return 1
  fi
  if [ -n "${YK_ACCENT}" ]; then
    YK_UI_ACCENT="${YK_ACCENT}"
  fi
  if [ -n "${NO_COLOR:-}" ]; then
    yk_ui_palette mono
  fi
}

yk_ui_forced() {
  [ "${YAKITSUKE_TEST_GUM:-}" = 1 ]
}

yk_ui_has_gum() {
  command -v gum >/dev/null 2>&1
}

yk_ui_prompts() {
  yk_ui_forced && return 0
  [ -t 0 ] && [ -t 2 ] && yk_ui_has_gum
}

yk_ui_err() {
  yk_ui_forced && return 0
  [ "${YK_UI_STEP}" = 1 ] && return 0
  [ -t 2 ] && yk_ui_has_gum
}

yk_ui_out() {
  yk_ui_forced && return 0
  [ -t 1 ] && yk_ui_has_gum
}

yk_gum() {
  if [ -n "${YK_UI_TEXT}" ]; then
    CLICOLOR_FORCE=1 gum "$@"
    return
  fi
  gum "$@"
}

yk_ui_ink() {
  yk_ui_colour="$1"
  shift
  if [ -z "${yk_ui_colour}" ]; then
    yk_gum style "$@"
    return
  fi
  yk_gum style --foreground "${yk_ui_colour}" "$@"
}

yk_ui_header() {
  yk_uh_name=$(yk_ui_ink "${YK_UI_ACCENT}" --bold -- "yakitsuke")
  yk_uh_number=$(yk_version | sed -n '1p')
  yk_uh_number="${yk_uh_number#yakitsuke }"
  yk_uh_version=$(yk_ui_ink "${YK_UI_MUTED}" -- "${yk_uh_number}")
  yk_uh_tagline=$(yk_ui_ink "${YK_UI_TEXT}" -- "${YK_TAGLINE}")
  yk_uh_top=$(yk_gum join --horizontal "${yk_uh_name}" "  " "${yk_uh_version}")
  yk_uh_body=$(yk_gum join --vertical "${yk_uh_top}" "${yk_uh_tagline}")
  printf '\n' >&2
  yk_gum style --border rounded --border-foreground "${YK_UI_ACCENT}" --padding "0 2" -- "${yk_uh_body}" >&2
  printf '\n' >&2
}

yk_ui_title() {
  printf '\n' >&2
  yk_ui_ink "${YK_UI_ACCENT}" --bold -- "$1" >&2
  printf '\n' >&2
}

yk_ui_titled() {
  if yk_ui_prompts; then
    yk_ui_title "$1"
  fi
}

yk_ui_lower_first() {
  printf '%s\n' "$1" | awk 'NR == 1 { a = substr($0, 1, 1); b = substr($0, 2, 1); if (a != tolower(a) && b != toupper(b)) { $0 = tolower(a) substr($0, 2) } } { print }'
}

yk_ui_log() {
  yk_ul_level="$1"
  yk_ul_text=$(yk_ui_lower_first "$2")
  case "${yk_ul_level}" in
  ERROR) yk_ul_colour="${YK_UI_ERR}" ;;
  WARN) yk_ul_colour="${YK_UI_WARN}" ;;
  *) yk_ul_colour="${YK_UI_OK}" ;;
  esac
  yk_ul_label=$(yk_ui_ink "${yk_ul_colour}" --bold -- "${yk_ul_level}")
  printf '%s yakitsuke: %s\n' "${yk_ul_label}" "${yk_ul_text}" >&2
}

yk_ui_choose() {
  yk_uc_header="$1"
  shift
  yk_gum choose --header "${yk_uc_header}" --cursor "> " --height 14 \
    --cursor.foreground "${YK_UI_ACCENT}" --selected.foreground "${YK_UI_ACCENT}" \
    --header.foreground "${YK_UI_TEXT}" "$@"
}

yk_ui_input() {
  yk_ui_header_text="$1"
  yk_ui_placeholder="$2"
  shift 2
  yk_gum input --header "${yk_ui_header_text}" --placeholder "${yk_ui_placeholder}" --prompt "> " \
    --prompt.foreground "${YK_UI_ACCENT}" --cursor.foreground "${YK_UI_ACCENT}" \
    --header.foreground "${YK_UI_TEXT}" --placeholder.foreground "${YK_UI_MUTED}" "$@"
}

yk_ui_write() {
  yk_gum write --header "$1" --placeholder "$2" --width 72 --height 8 --show-line-numbers \
    --cursor.foreground "${YK_UI_ACCENT}" --header.foreground "${YK_UI_TEXT}" \
    --placeholder.foreground "${YK_UI_MUTED}"
}

yk_ui_confirm() {
  yk_ucf_prompt="$1"
  yk_ucf_yes="$2"
  yk_ucf_no="$3"
  shift 3
  yk_gum confirm "${yk_ucf_prompt}" --affirmative "${yk_ucf_yes}" --negative "${yk_ucf_no}" \
    --prompt.foreground "${YK_UI_TEXT}" --selected.background "${YK_UI_ACCENT}" \
    --unselected.background "${YK_UI_SURFACE}" "$@"
}

yk_ui_summary() {
  yk_us2_pairs=$(($# / 2))
  while [ "${yk_us2_pairs}" -gt 0 ]; do
    yk_us2_label=$(printf '%-7s' "$1")
    yk_us2_label=$(yk_ui_ink "${YK_UI_MUTED}" -- "${yk_us2_label}")
    yk_us2_value=$(yk_ui_ink "${YK_UI_TEXT}" --bold -- "$2")
    shift 2
    set -- "$@" "${yk_us2_label} ${yk_us2_value}"
    yk_us2_pairs=$((yk_us2_pairs - 1))
  done
  printf '\n'
  yk_gum style --border rounded --border-foreground "${YK_UI_MUTED}" --padding "0 1" -- "$@"
  printf '\n'
}

yk_ui_spin() {
  yk_us_title="$1"
  yk_us_log="$2"
  shift 2
  (YK_UI_STEP=1 && "$@") 2>"${yk_us_log}" &
  yk_us_pid=$!
  if ! yk_ui_spin_wait "${yk_us_title}" "${yk_us_pid}"; then
    kill "${yk_us_pid}" 2>/dev/null
    exit 130
  fi
  yk_us_status=0
  wait "${yk_us_pid}" || yk_us_status=$?
  cat "${yk_us_log}" >&2
  return "${yk_us_status}"
}

yk_ui_spin_wait() {
  # shellcheck disable=SC2016
  yk_uw_loop='while kill -0 "$1" 2>/dev/null; do sleep 0.1; done'
  yk_gum spin --spinner dot --spinner.foreground "${YK_UI_ACCENT}" --title.foreground "${YK_UI_TEXT}" --title "$1" -- sh -c "${yk_uw_loop}" _ "$2" >&2
}

yk_ui_table() {
  yk_ut_line="-"
  if [ -n "${YK_UI_TEXT}" ]; then
    yk_ut_line=$(printf '\342\224\200')
  fi
  yk_ut_body=$(yk_ui_table_body "${yk_ut_line}")
  yk_gum style --border rounded --border-foreground "${YK_UI_MUTED}" --padding "0 1" -- "${yk_ut_body}"
}

yk_ui_table_body() {
  LC_ALL=C awk -F '\t' -v acc="${YK_UI_ACCENT}" -v ok="${YK_UI_OK}" -v warn="${YK_UI_WARN}" \
    -v bad="${YK_UI_ERR}" -v txt="${YK_UI_TEXT}" -v mut="${YK_UI_MUTED}" -v dash="$1" \
    -f "${YK_LIB}/table.awk"
}

yk_ui_done() {
  printf '\n'
  yk_ui_ink "${YK_UI_OK}" --bold -- "$1"
}

yk_ui_badge() {
  yk_ub_colour="$1"
  shift
  if [ -z "${yk_ub_colour}" ]; then
    yk_gum style --bold --underline --padding "0 1" -- "$*"
    return
  fi
  yk_gum style --background "${yk_ub_colour}" --foreground "#1E1E2E" --bold --padding "0 1" -- "$*"
}

yk_ui_chip() {
  if [ -z "${YK_UI_SURFACE}" ]; then
    yk_gum style --padding "0 1" -- "$1"
    return
  fi
  yk_gum style --background "${YK_UI_SURFACE}" --foreground "${YK_UI_TEXT}" --padding "0 1" -- "$1"
}

yk_ui_danger() {
  yk_ud_title=$(yk_ui_ink "${YK_UI_ERR}" --bold -- "$1")
  shift
  yk_gum style --border thick --border-foreground "${YK_UI_ERR}" --padding "0 1" -- "${yk_ud_title}" "$@" >&2
}

yk_ui_markdown() {
  awk '
    NR == 1 {
      split($0, head, " - ")
      printf "# %s\n\n%s\n", head[1], head[2]
      next
    }
    /^[a-z][a-z ]*:$/ {
      if (open) { print "```" }
      printf "\n## %s\n\n```text\n", toupper(substr($0, 1, 1)) substr($0, 2, length($0) - 2)
      open = 1
      next
    }
    { print }
    END { if (open) { print "```" } }
  '
}
