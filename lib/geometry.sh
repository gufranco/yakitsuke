#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

yk_source_fps() {
  awk -v r="$1" 'BEGIN { split(r, p, "/"); printf "%.4f\n", (p[2] + 0 > 0) ? p[1] / p[2] : p[1] + 0 }'
}

yk_rate_family() {
  awk -v f="$1" 'BEGIN {
    if ((f > 24.5 && f < 26.5) || (f > 49 && f < 51)) print "pal"
    else if (f > 23.5 && f < 24.5) print "film"
    else print "ntsc"
  }'
}

yk_choose_standard() {
  yk_cs_fps="$(yk_source_fps "${YK_SRC_FPS}")"
  yk_cs_family="$(yk_rate_family "${yk_cs_fps}")"
  [ -n "${YK_STANDARD}" ] || YK_STANDARD="${yk_cs_family}"
  YK_SPEED=1
  if [ "${YK_STANDARD}" = pal ] && [ "${yk_cs_family}" = film ]; then
    YK_SPEED="$(awk -v r="${YK_SRC_FPS}" 'BEGIN { split(r, p, "/"); f = (p[2] + 0 > 0) ? p[1] / p[2] : p[1] + 0; printf "%.6f\n", 25 / f }')"
  fi
  yk_standard_params
}

yk_standard_params() {
  case "${YK_STANDARD}" in
  pal)
    YK_RASTER_H=288 YK_FPS=25 YK_RATE_CODE=3 YK_NORM=p YK_GOP=12 YK_MATRIX_OUT=bt470bg
    ;;
  film)
    YK_RASTER_H=240 YK_FPS=24000/1001 YK_RATE_CODE=1 YK_NORM=n YK_GOP=12 YK_MATRIX_OUT=smpte170m
    ;;
  *)
    YK_RASTER_H=240 YK_FPS=30000/1001 YK_RATE_CODE=4 YK_NORM=n YK_GOP=15 YK_MATRIX_OUT=smpte170m
    ;;
  esac
}

yk_display_aspect() {
  awk -v w="$1" -v h="$2" -v sar="$3" 'BEGIN {
    num = 1; den = 1
    if (split(sar, p, ":") == 2 && p[1] + 0 > 0 && p[2] + 0 > 0) { num = p[1] + 0; den = p[2] + 0 }
    printf "%.10f\n", (w * num) / (h * den)
  }'
}

yk_fit_geometry() {
  awk -v mode="$1" -v sw="$2" -v sh="$3" -v dar="$4" -v cw="${YK_CANVAS_W}" -v ch="${YK_CANVAS_H}" '
    function even(v) { v = int(v / 2 + 0.5) * 2; return (v < 2 ? 2 : v) }
    BEGIN {
      disc = 4.0 / 3.0
      if (mode == "crop") {
        if (dar > disc) { w = even(sw * disc / dar); h = even(sh) } else { w = even(sw); h = even(sh * dar / disc) }
        printf "%d %d %d %d %d %d 0 0\n", w, h, int((sw - w) / 2), int((sh - h) / 2), cw, ch
        exit
      }
      if (dar >= disc) { pw = cw; ph = even(cw / dar) } else { pw = even(ch * dar); ph = ch }
      printf "0 0 0 0 %d %d %d %d\n", pw, ph, int((cw - pw) / 2), int((ch - ph) / 2)
    }'
}

yk_geometry() {
  YK_ACTIVE_W="${YK_SRC_W}" YK_ACTIVE_H="${YK_SRC_H}" YK_BORDER_X=0 YK_BORDER_Y=0
  if [ "${YK_BORDERS}" = auto ]; then
    yk_ge_box="$(yk_detect_borders "$1")"
    read -r YK_ACTIVE_W YK_ACTIVE_H YK_BORDER_X YK_BORDER_Y <<EOF
${yk_ge_box}
EOF
  fi
  YK_DAR="$(yk_display_aspect "${YK_ACTIVE_W}" "${YK_ACTIVE_H}" "${YK_SRC_SAR}")"
  yk_ge_fit="$(yk_fit_geometry "${YK_FIT}" "${YK_ACTIVE_W}" "${YK_ACTIVE_H}" "${YK_DAR}")"
  read -r YK_CROP_W YK_CROP_H YK_CROP_X YK_CROP_Y YK_PIC_W YK_PIC_H YK_PAD_X YK_PAD_Y <<EOF
${yk_ge_fit}
EOF
}

yk_bordered() {
  [ "${YK_ACTIVE_W}" != "${YK_SRC_W}" ] || [ "${YK_ACTIVE_H}" != "${YK_SRC_H}" ]
}
