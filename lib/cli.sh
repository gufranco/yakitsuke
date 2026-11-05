#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

yk_usage() {
  if yk_ui_out; then
    yk_usage_text | yk_ui_markdown | yk_gum format --theme "${YK_UI_HELP}"
    return 0
  fi
  yk_usage_text
}

yk_usage_text() {
  cat <<'USAGE'
yakitsuke - burn any video onto Video CD or Super Video CD images

usage:
  yakitsuke                  ask for the video and subtitles, step by step
  yakitsuke [options] <video> [subtitles]
                             encode the video into as many disc images as it
                             needs
  yakitsuke doctor           check the tools yakitsuke needs
  yakitsuke version          print the version
  yakitsuke help             print this page

disc:
  --format vcd|svcd          Video CD 2.0 (default), or Super Video CD 1.0:
                             sharper MPEG-2, about 48 minutes per 80-minute disc
  --cd74 | --cd80 | --cd90   74, 80 (default) or 90 minute media
  --disc-minutes N           explicit media length in minutes
  --overlap SECONDS          footage repeated at each disc seam (default 30)
  --scene-snap SECONDS       move seams onto the nearest scene change within
                             this many seconds, 0 disables (default 15)
  --title TEXT               volume label and album id (default: file name)
  --chapters MINUTES         entry point every N minutes, snapped to scene
                             changes, 0 disables (default 5)

picture:
  --ntsc | --pal | --film    force 29.97, 25 or 23.976 fps (default: from the
                             source; 24 fps film stays film, never duplicated)
  --crop | --letterbox       fill the frame, cutting what spills over the
                             sides (default), or keep the whole frame with bars
  --aspect auto|4:3|16:9     Super Video CD shape; auto picks 16:9 for a
                             source 1.55:1 or wider (default auto)
  --borders auto|off         strip baked-in black bars first (default auto)
  --deinterlace MODE         auto, on, ivtc or off (default auto)
  --denoise SIGMA            fftdnoiz sigma, e.g. 1.5 (default off)
  --sharpen | --no-sharpen   mild sharpening after the downscale (default on)
  --no-color-convert         keep the source matrix instead of BT.601

sound:
  --audio-track N            source audio stream index (default 0)
  --normalize                EBU R128 loudness, measured first for an exact fix

subtitles:
  --sub-track N              burn an embedded text subtitle stream
  --sub-color auto|white|yellow
                             default auto: white, or yellow for a
                             black-and-white film
  --sub-box auto|always|never
                             default auto: a box behind lines that sit on a
                             bright or busy picture, an outline elsewhere
  --sub-offset SECONDS       shift every subtitle, negative pulls them earlier
  --sub-style SPEC           ASS style overrides, e.g. Fontsize=22

encoder and output:
  --encoder auto|mpeg2enc|ffmpeg
                             default auto: mpeg2enc when mjpegtools is
                             installed, ffmpeg for Super Video CD except
                             NTSC film
  --output-dir DIR           destination (default: next to the source)
  --keep-mpeg                keep the MPEG program streams
  --force                    overwrite existing images
  --resume                   keep discs that already exist and verify
  --preview SECONDS          encode one short sample from the middle
  --dry-run                  print the plan and stop
  --json                     print the result as one JSON object, for scripts
  --theme NAME               colours of the terminal interface, see notes

environment:
  YAKITSUKE_FORMAT           vcd or svcd, the default for --format
  YAKITSUKE_FFMPEG           ffmpeg to use; otherwise the first build on PATH
                             with the filters the run needs

notes:
  Every option that takes a value also takes the form --name=value, and --
  ends the options. A file named help, doctor or version is encoded by giving
  its path, such as ./help.

  On a terminal with gum installed, yakitsuke draws its prompts, summary and
  progress with gum. --theme, else YAKITSUKE_THEME, else KODOUGU_THEME picks
  the colours: kodougu, catppuccin-mocha, catppuccin-latte, dracula, nord,
  gruvbox, tokyo-night or mono. KODOUGU_ACCENT=#RRGGBB replaces only the
  accent, and NO_COLOR turns colour off.

examples:
  yakitsuke movie.mkv
  yakitsuke --cd74 movie.mkv movie.srt
  yakitsuke --pal --crop --sub-style 'Fontsize=22' movie.mkv movie.srt
USAGE
}

yk_cli_hint() {
  yk_error "$1. run '${YK_PROG} help' for usage."
}

yk_cli_version() {
  yk_cv_platform="$(uname -sr)" || yk_cv_platform="unknown"
  if yk_ui_out; then
    yk_cv_text="$(yk_version)"
    yk_cv_badge="$(yk_ui_badge "${YK_UI_ACCENT}" "${yk_cv_text}")"
    yk_cv_chip="$(yk_ui_chip "platform ${yk_cv_platform}")"
    yk_gum join --horizontal "${yk_cv_badge}" " " "${yk_cv_chip}"
    return 0
  fi
  yk_version
  printf 'platform: %s\n' "${yk_cv_platform}"
}

yk_doctor_row() {
  if yk_ui_out; then
    case "$2" in
    ok) yk_dw_state="@ok:ok" ;;
    *) yk_dw_state="@bad:$2" ;;
    esac
    YK_DOCTOR_ROWS="${YK_DOCTOR_ROWS}$1	${yk_dw_state}	$3
"
    return 0
  fi
  printf '%-18s %-8s %s\n' "$1" "$2" "$3"
}

yk_doctor_report() {
  if ! yk_ui_out; then
    return 0
  fi
  printf 'Tool\tState\tDetail\n%s' "${YK_DOCTOR_ROWS}" | yk_ui_table
  if [ "$1" -ne 0 ]; then
    yk_ui_log ERROR "a required tool is missing. install it and run yakitsuke doctor again."
    return 0
  fi
  yk_ui_done "Ready. Every tool yakitsuke needs is here."
}

yk_doctor_gum() {
  yk_dg_found="$(command -v gum 2>/dev/null || true)"
  if [ -z "${yk_dg_found}" ]; then
    yk_doctor_row gum missing "install with: brew install gum, or see https://github.com/charmbracelet/gum"
    return 1
  fi
  yk_dg_raw="$(gum --version 2>/dev/null || true)"
  yk_dg_version="$(yk_flavor_version "${yk_dg_raw}")"
  yk_doctor_row gum ok "${yk_dg_found}${yk_dg_version:+, ${yk_dg_version}}"
}

yk_flavor_version() {
  printf '%s\n' "$1" | awk '{
    for (i = 1; i <= NF; i++) {
      t = $i
      gsub(/[,;()]/, "", t)
      sub(/^v/, "", t)
      if (t ~ /^[0-9]+(\.[0-9]+)+[a-z0-9]*$/ || t ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/) { print t; exit }
    }
  }'
}

yk_tool_line() {
  yk_tl_line="$(printf '%s\n' "$1" | awk '/BusyBox|This is not GNU/ { print; exit }')"
  if [ -z "${yk_tl_line}" ]; then
    yk_tl_line="$(printf '%s\n' "$1" | sed -n '1p')"
  fi
  printf '%s\n' "${yk_tl_line}"
}

yk_tool_flavor() {
  yk_tf_raw="$("$1" --version 2>&1 </dev/null)" || true
  yk_tf_text="$(yk_tool_line "${yk_tf_raw}")"
  yk_tf_version="$(yk_flavor_version "${yk_tf_text}")"
  yk_tf_os="${YAKITSUKE_OS:-}"
  [ -n "${yk_tf_os}" ] || yk_tf_os="$(uname -s)"
  case "${yk_tf_text}" in
  *uutils*) yk_tf_name=uutils ;;
  *BusyBox*) yk_tf_name=busybox ;;
  *"This is not GNU"*)
    yk_tf_name=busybox
    yk_tf_version=""
    ;;
  *GNU* | *GLIBC* | *"(coreutils)"* | *"(diffutils)"*) yk_tf_name=gnu ;;
  *mawk*) yk_tf_name=mawk ;;
  *"awk version"* | *"(Darwin)"*) yk_tf_name=bsd ;;
  *)
    yk_tf_version=""
    case "$1:${yk_tf_os}" in
    *uutils*:* | */cargo/*:*) yk_tf_name=uutils ;;
    *:Darwin | *:*BSD) yk_tf_name=bsd ;;
    *) yk_tf_name=unknown ;;
    esac
    ;;
  esac
  printf '%s%s\n' "${yk_tf_name}" "${yk_tf_version:+ ${yk_tf_version}}"
}

yk_doctor_found() {
  yk_dfo_note=""
  case "${1##*/}" in
  awk | sed | iconv) yk_dfo_note="$(yk_tool_flavor "$1")" ;;
  *) ;;
  esac
  printf '%s%s\n' "$1" "${yk_dfo_note:+, ${yk_dfo_note}}"
}

yk_doctor_tool() {
  yk_dt_found="$(command -v "$1" 2>/dev/null || true)"
  if [ -n "${yk_dt_found}" ]; then
    yk_dt_detail="$(yk_doctor_found "${yk_dt_found}")"
    yk_doctor_row "$1" ok "${yk_dt_detail}"
    return 0
  fi
  yk_doctor_row "$1" missing "$3"
  [ "$2" = required ] && return 1
  return 0
}

yk_doctor_filter() {
  yk_df_check=yk_has_filter
  [ "$1" = subtitles ] && yk_df_check=yk_has_subtitle_alpha
  [ "$1" = soxr ] && yk_df_check=yk_has_soxr
  if [ -n "${YK_FFMPEG}" ] && "${yk_df_check}" "${YK_FFMPEG}" "$1"; then
    yk_doctor_row "ffmpeg $1" ok "${YK_FFMPEG}"
    return 0
  fi
  yk_doctor_row "ffmpeg $1" missing "$2"
  return 0
}

yk_doctor() {
  yk_dr_status=0
  yk_doctor_gum || yk_dr_status=1
  yk_doctor_tool ffmpeg required "brew install ffmpeg, or apt install ffmpeg" || yk_dr_status=1
  yk_doctor_tool ffprobe required "installed with ffmpeg" || yk_dr_status=1
  yk_doctor_tool vcdxbuild required "brew install vcdimager, or apt install vcdimager" || yk_dr_status=1
  for yk_dr_tool in awk sed iconv file; do
    yk_doctor_tool "${yk_dr_tool}" required "required" || yk_dr_status=1
  done
  yk_doctor_tool mpeg2enc optional "mjpegtools, the better encoder"
  yk_doctor_tool mplex optional "mjpegtools, muxes mpeg2enc output"
  YK_FFMPEG="$(yk_resolve_ffmpeg yes 2>/dev/null || yk_resolve_ffmpeg no 2>/dev/null || true)"
  yk_doctor_filter subtitles "needed to burn subtitles: brew install ffmpeg-full"
  yk_doctor_filter zscale "16-bit colour conversion: an ffmpeg built with zimg"
  yk_doctor_filter soxr "finer audio resampling: an ffmpeg built with libsoxr"
  yk_doctor_report "${yk_dr_status}"
  return "${yk_dr_status}"
}

yk_interactive() {
  [ "${YAKITSUKE_INTERACTIVE:-}" = 1 ] && return 0
  [ -t 0 ]
}

yk_prompt() {
  if yk_ui_prompts; then
    yk_pd_answer="$(yk_ui_input "${1%%, *}" "${1#*, }")" || return 1
    printf '%s\n' "${yk_pd_answer:-$2}"
    return 0
  fi
  if [ -n "$2" ]; then
    printf '%s [%s]: ' "$1" "$2" >&2
  else
    printf '%s: ' "$1" >&2
  fi
  yk_pr_answer=""
  IFS= read -r yk_pr_answer || [ -n "${yk_pr_answer}" ] || return 1
  printf '%s\n' "${yk_pr_answer:-$2}"
}

yk_ask_required() {
  yk_ar_tries=0
  while [ "${yk_ar_tries}" -lt 3 ]; do
    yk_ar_value="$(yk_prompt "$1" "")" || return 1
    if [ -n "${yk_ar_value}" ]; then
      printf '%s\n' "${yk_ar_value}"
      return 0
    fi
    yk_ar_tries=$((yk_ar_tries + 1))
  done
  yk_cli_hint "$2"
  return 1
}
