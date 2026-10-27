#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

yk_usage() {
  cat <<'USAGE'
yakitsuke - burn any video onto Video CD: VCD 2.0 BIN/CUE images, split across discs

usage:
  yakitsuke                               ask for the video and subtitles, step by step
  yakitsuke [options] <video> [subtitles]
                                          encode the video into as many disc images as
                                          it needs
  yakitsuke doctor                        check the tools yakitsuke needs
  yakitsuke version                       print the version
  yakitsuke help                          print this page

disc:
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
  --letterbox | --crop       fit the whole frame with bars (default), or fill it
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
                             default auto: white, yellow for black-and-white film
  --sub-box auto|always|never
                             default auto: a box behind lines that sit on a
                             bright or busy picture, an outline elsewhere
  --sub-offset SECONDS       shift every subtitle, negative pulls them earlier
  --sub-style SPEC           ASS style overrides, e.g. Fontsize=22

encoder and output:
  --encoder auto|mpeg2enc|ffmpeg
                             default auto: mpeg2enc when mjpegtools is installed
  --output-dir DIR           destination (default: next to the source)
  --keep-mpeg                keep the MPEG-1 program streams
  --force                    overwrite existing images
  --resume                   keep discs that already exist and verify
  --preview SECONDS          encode one short sample from the middle
  --dry-run                  print the plan and stop

environment:
  YAKITSUKE_FFMPEG           ffmpeg to use; otherwise the first build on PATH
                             with the filters the run needs

notes:
  Every option that takes a value also takes the form --name=value, and --
  ends the options. A file named help, doctor or version is encoded by giving
  its path, such as ./help.

examples:
  yakitsuke movie.mkv
  yakitsuke --cd74 movie.mkv movie.srt
  yakitsuke --pal --crop --sub-style 'Fontsize=22' movie.mkv movie.srt
USAGE
}

yk_cli_hint() {
  printf "%s: %s. run '%s help' for usage.\n" "${YK_PROG}" "$1" "${YK_PROG}" >&2
}

yk_cli_version() {
  yk_version
  yk_cv_platform="$(uname -sr)" || yk_cv_platform="unknown"
  printf 'platform: %s\n' "${yk_cv_platform}"
}

yk_doctor_row() {
  printf '%-18s %-8s %s\n' "$1" "$2" "$3"
}

yk_doctor_tool() {
  yk_dt_found="$(command -v "$1" 2>/dev/null || true)"
  if [ -n "${yk_dt_found}" ]; then
    yk_doctor_row "$1" ok "${yk_dt_found}"
    return 0
  fi
  yk_doctor_row "$1" missing "$3"
  [ "$2" = required ] && return 1
  return 0
}

yk_doctor_filter() {
  yk_df_check=yk_has_filter
  [ "$1" = subtitles ] && yk_df_check=yk_has_subtitle_alpha
  if [ -n "${YK_FFMPEG}" ] && "${yk_df_check}" "${YK_FFMPEG}" "$1"; then
    yk_doctor_row "ffmpeg $1" ok "${YK_FFMPEG}"
    return 0
  fi
  yk_doctor_row "ffmpeg $1" missing "$2"
  return 0
}

yk_doctor() {
  yk_dr_status=0
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
  return "${yk_dr_status}"
}

yk_interactive() {
  [ "${YK_INTERACTIVE:-}" = 1 ] && return 0
  [ -t 0 ]
}

yk_prompt() {
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
