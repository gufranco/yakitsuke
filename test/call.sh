#!/bin/sh
[ -n "${ZSH_VERSION:-}" ] && emulate sh

YK_LIB="$(cd "$(dirname "$0")/../lib" && pwd)" || exit 1
YK_SHARE="$(cd "$(dirname "$0")/../share" && pwd)" || exit 1

# shellcheck source=SCRIPTDIR/../lib/core.sh
. "${YK_LIB}/core.sh"
# shellcheck source=SCRIPTDIR/../lib/cli.sh
. "${YK_LIB}/cli.sh"
# shellcheck source=SCRIPTDIR/../lib/args.sh
. "${YK_LIB}/args.sh"
# shellcheck source=SCRIPTDIR/../lib/probe.sh
. "${YK_LIB}/probe.sh"
# shellcheck source=SCRIPTDIR/../lib/geometry.sh
. "${YK_LIB}/geometry.sh"
# shellcheck source=SCRIPTDIR/../lib/plan.sh
. "${YK_LIB}/plan.sh"
# shellcheck source=SCRIPTDIR/../lib/subs.sh
. "${YK_LIB}/subs.sh"
# shellcheck source=SCRIPTDIR/../lib/encode.sh
. "${YK_LIB}/encode.sh"
# shellcheck source=SCRIPTDIR/../lib/image.sh
. "${YK_LIB}/image.sh"
# shellcheck source=SCRIPTDIR/../lib/run.sh
. "${YK_LIB}/run.sh"

YK_FFMPEG="$(yk_resolve_ffmpeg no)"
YK_FFPROBE="$(yk_resolve_ffprobe)"

call_probe() {
  YK_INPUT="$1"
  yk_run_probe || return 1
  printf 'duration=%s size=%sx%s fps=%s audio=%s\n' "${YK_DURATION}" "${YK_SRC_W}" "${YK_SRC_H}" "${YK_SRC_FPS}" "${YK_HAS_AUDIO}"
}

call_standard() {
  YK_SRC_FPS="$1"
  YK_STANDARD="${2:-}"
  yk_choose_standard
  printf '%s %s %s %s %s\n' "${YK_STANDARD}" "${YK_RASTER_H}" "${YK_FPS}" "${YK_RATE_CODE}" "${YK_SPEED}"
}

call_detect() {
  YK_DURATION="$(yk_probe_duration "$2")"
  YK_SRC_W="$(yk_probe_stream v:0 width "$2")"
  YK_SRC_H="$(yk_probe_stream v:0 height "$2")"
  "$1" "$2"
}

call_subs() {
  YK_INPUT="$1"
  YK_SUBTITLES="${2:-}"
  YK_SUB_TRACK="${3:-}"
  YK_WORK="$(mktemp -d "${TMPDIR:-/tmp}/yk-call.XXXXXX")"
  call_probe "$1" >/dev/null || return 1
  yk_run_analyse
  yk_subs_prepare || return 1
  [ -z "${YK_SUB_MASTER}" ] || cat "${YK_SUB_MASTER}"
  rm -rf "${YK_WORK}"
}

call_graph() {
  [ "${YK_SRC_W}" != 0 ] || YK_SRC_W=1920
  [ "${YK_SRC_H}" != 0 ] || YK_SRC_H=1080
  [ "${YK_ACTIVE_W}" != 0 ] || YK_ACTIVE_W="${YK_SRC_W}"
  [ "${YK_ACTIVE_H}" != 0 ] || YK_ACTIVE_H="${YK_SRC_H}"
  YK_STANDARD="${YK_STANDARD:-pal}"
  yk_standard_params
  yk_inner_geometry
  yk_filter_graph "${1:-10}"
}

call_progress() {
  YK_WORK="$1"
  YK_PROGRESS_LABEL="Disc 1 of 1, encoding"
  yk_progress_show "$2" "$3"
}

call_snap_plan() {
  YK_USABLE="$3"
  yk_snap_plan "$1" "$2" "$4" "$5"
}

"$@"
