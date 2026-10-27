#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

yk_args_value() {
  case "$1" in
  disc-minutes) YK_DISC_MINUTES="$2" ;;
  overlap) YK_OVERLAP="$2" ;;
  scene-snap) YK_SCENE_SNAP="$2" ;;
  title) YK_TITLE="$2" ;;
  chapters) YK_CHAPTERS="$2" ;;
  borders) YK_BORDERS="$2" ;;
  deinterlace) YK_DEINTERLACE="$2" ;;
  denoise) YK_DENOISE="$2" ;;
  audio-track) YK_AUDIO_TRACK="$2" ;;
  sub-track) YK_SUB_TRACK="$2" ;;
  sub-style) YK_SUB_STYLE="$2" ;;
  sub-color) YK_SUB_COLOR="$2" ;;
  sub-box) YK_SUB_BOX="$2" ;;
  sub-offset) YK_SUB_OFFSET="$2" ;;
  preview) YK_PREVIEW="$2" ;;
  output-dir) YK_OUTPUT_DIR="$2" ;;
  encoder) YK_ENCODER="$2" ;;
  *) return 1 ;;
  esac
}

yk_args_flag() {
  case "$1" in
  cd74) YK_DISC_MINUTES=74 ;;
  cd80) YK_DISC_MINUTES=80 ;;
  cd90) YK_DISC_MINUTES=90 ;;
  ntsc) YK_STANDARD=ntsc ;;
  pal) YK_STANDARD=pal ;;
  film) YK_STANDARD=film ;;
  letterbox) YK_FIT=letterbox ;;
  crop) YK_FIT=crop ;;
  sharpen) YK_SHARPEN=yes ;;
  no-sharpen) YK_SHARPEN=no ;;
  no-color-convert) YK_COLOR_CONVERT=no ;;
  normalize) YK_NORMALIZE=yes ;;
  keep-mpeg) YK_KEEP_MPEG=yes ;;
  force) YK_FORCE=yes ;;
  resume) YK_RESUME=yes ;;
  dry-run) YK_DRY_RUN=yes ;;
  *) return 1 ;;
  esac
}

yk_args_positional() {
  if [ -z "${YK_INPUT}" ]; then
    YK_INPUT="$1"
  elif [ -z "${YK_SUBTITLES}" ]; then
    YK_SUBTITLES="$1"
  else
    yk_cli_hint "unexpected extra argument '$1'"
    return 1
  fi
}

yk_args_assign() {
  yk_aa_name="${1%%=*}"
  yk_args_value "${yk_aa_name#--}" "${1#*=}" && return 0
  yk_cli_hint "unknown option '${yk_aa_name}'"
  return 1
}

yk_args_long() {
  YK_ARGS_USED=1
  yk_args_flag "${1#--}" && return 0
  if ! yk_args_value "${1#--}" "$3"; then
    yk_cli_hint "unknown option '$1'"
    return 1
  fi
  if [ "$2" -lt 2 ]; then
    yk_cli_hint "option '$1' needs a value"
    return 1
  fi
  YK_ARGS_USED=2
}

yk_args_one() {
  YK_ARGS_USED=1
  case "$1" in
  --) YK_ARGS_DONE=yes ;;
  --*=*) yk_args_assign "$1" ;;
  --?*) yk_args_long "$1" "$2" "$3" ;;
  -?*)
    yk_cli_hint "unknown option '$1'"
    return 1
    ;;
  *) yk_args_positional "$1" ;;
  esac
}

yk_args_parse() {
  YK_ARGS_DONE=no
  while [ "$#" -gt 0 ]; do
    if [ "${YK_ARGS_DONE}" = yes ]; then
      yk_args_positional "$1" || return 1
      shift
      continue
    fi
    yk_args_one "$1" "$#" "${2:-}" || return 1
    shift "${YK_ARGS_USED}"
  done
}

yk_check_choice() {
  case " $3 " in
  *" $2 "*) return 0 ;;
  *) ;;
  esac
  yk_error "--$1 must be one of: $3. Got: $2"
  return 1
}

yk_check_uint() {
  yk_is_uint "$2" && return 0
  yk_error "--$1 must be a whole number of $3, got: $2"
  return 1
}

yk_args_validate() {
  yk_check_uint disc-minutes "${YK_DISC_MINUTES}" minutes || return 1
  if [ "${YK_DISC_MINUTES}" -lt 1 ]; then
    yk_error "--disc-minutes must be at least 1, got: ${YK_DISC_MINUTES}"
    return 1
  fi
  yk_check_uint overlap "${YK_OVERLAP}" seconds || return 1
  yk_check_uint scene-snap "${YK_SCENE_SNAP}" seconds || return 1
  yk_check_uint chapters "${YK_CHAPTERS}" minutes || return 1
  yk_check_uint preview "${YK_PREVIEW}" seconds || return 1
  yk_check_uint audio-track "${YK_AUDIO_TRACK}" "stream index" || return 1
  if [ -n "${YK_SUB_TRACK}" ]; then
    yk_check_uint sub-track "${YK_SUB_TRACK}" "stream index" || return 1
  fi
  yk_check_choice deinterlace "${YK_DEINTERLACE}" "auto on ivtc off" || return 1
  yk_check_choice borders "${YK_BORDERS}" "auto off" || return 1
  yk_check_choice sub-color "${YK_SUB_COLOR}" "auto white yellow" || return 1
  yk_check_choice sub-box "${YK_SUB_BOX}" "auto always never" || return 1
  yk_check_choice encoder "${YK_ENCODER}" "auto mpeg2enc ffmpeg" || return 1
  yk_args_validate_values
}

yk_args_validate_values() {
  if ! yk_is_number "${YK_SUB_OFFSET}"; then
    yk_error "--sub-offset must be a number of seconds, got: ${YK_SUB_OFFSET}"
    return 1
  fi
  if [ "${YK_DENOISE}" != off ] && ! yk_is_number "${YK_DENOISE}"; then
    yk_error "--denoise must be off or an fftdnoiz sigma such as 1.5, got: ${YK_DENOISE}"
    return 1
  fi
  if [ "${YK_FORCE}" = yes ] && [ "${YK_RESUME}" = yes ]; then
    yk_error "--force and --resume contradict each other; pick one"
    return 1
  fi
  return 0
}
