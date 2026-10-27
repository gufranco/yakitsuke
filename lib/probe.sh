#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

yk_has_filter() {
  "$1" -hide_banner -filters 2>/dev/null | awk -v want="$2" '$2 == want { hit = 1 } END { exit !hit }'
}

yk_has_subtitle_alpha() {
  "$1" -hide_banner -h filter=subtitles 2>/dev/null | awk '$1 == "alpha" { hit = 1 } END { exit !hit }'
}

yk_ffmpeg_candidates() {
  [ -n "${YAKITSUKE_FFMPEG:-}" ] && printf '%s\n' "${YAKITSUKE_FFMPEG}"
  printf '%s\n' "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/ffmpeg-full/bin/ffmpeg" /usr/local/opt/ffmpeg-full/bin/ffmpeg
  command -v ffmpeg 2>/dev/null || true
}

yk_resolve_ffmpeg() {
  yk_rf_list="$(yk_ffmpeg_candidates)"
  yk_rf_found=""
  while IFS= read -r yk_rf_candidate; do
    [ -n "${yk_rf_found}" ] && continue
    [ -n "${yk_rf_candidate}" ] && [ -x "${yk_rf_candidate}" ] || continue
    if [ "$1" = yes ] && ! yk_has_subtitle_alpha "${yk_rf_candidate}"; then
      continue
    fi
    yk_rf_found="${yk_rf_candidate}"
  done <<EOF
${yk_rf_list}
EOF
  [ -n "${yk_rf_found}" ] || return 1
  printf '%s\n' "${yk_rf_found}"
}

yk_resolve_ffprobe() {
  yk_rp_probe="${YK_FFMPEG%/*}/ffprobe"
  [ -x "${yk_rp_probe}" ] || yk_rp_probe="$(command -v ffprobe 2>/dev/null || true)"
  [ -n "${yk_rp_probe}" ] || return 1
  printf '%s\n' "${yk_rp_probe}"
}

yk_probe_format() {
  "${YK_FFPROBE}" -v error -show_entries "format=$1" -of default=noprint_wrappers=1:nokey=1 "$2" 2>/dev/null | sed -n '1p'
}

yk_probe_stream() {
  "${YK_FFPROBE}" -v error -select_streams "$1" -show_entries "stream=$2" \
    -of default=noprint_wrappers=1:nokey=1 "$3" 2>/dev/null | sed -n '1p'
}

yk_probe_duration() {
  yk_pd_value="$(yk_probe_format duration "$1")"
  case "${yk_pd_value}" in
  '' | N/A) yk_pd_value="$(yk_probe_stream v:0 duration "$1")" ;;
  *) ;;
  esac
  yk_greater "${yk_pd_value:-0}" 0 || return 1
  printf '%s\n' "${yk_pd_value}"
}

yk_track_list() {
  "${YK_FFPROBE}" -v error -show_entries "stream=codec_type,codec_name,channels:stream_tags=language,title" \
    -of csv=p=0 "$1" 2>/dev/null | awk -F, '
    $2 == "audio" {
      line = "audio " na++ ": " $1
      if ($3 != "") line = line ", " $3 "ch"
      if ($4 != "") line = line ", " $4
      if ($5 != "") line = line ", " $5
      print line
    }
    $2 == "subtitle" {
      line = "subtitle " ns++ ": " $1
      if ($3 != "") line = line ", " $3
      if ($4 != "") line = line ", " $4
      print line
    }'
}

yk_detect_field_mode() {
  yk_fm_seek="$(awk -v d="${YK_DURATION}" 'BEGIN { printf "%.2f", (d > 60 ? d * 0.1 : 0) }')"
  "${YK_FFMPEG}" -hide_banner -nostdin -ss "${yk_fm_seek}" -i "$1" -frames:v 300 -filter:v idet -an -f null - 2>&1 |
    awk -f "${YK_LIB}/fieldmode.awk"
}

yk_detect_borders() {
  for yk_db_fraction in 10 30 50 70 90; do
    yk_db_seek="$(awk -v d="${YK_DURATION}" -v f="${yk_db_fraction}" 'BEGIN { printf "%.2f", d * f / 100 }')"
    "${YK_FFMPEG}" -hide_banner -nostdin -ss "${yk_db_seek}" -i "$1" -frames:v 60 -vf cropdetect=limit=24:round=2:reset=0 -an -f null - 2>&1 |
      grep -o 'crop=[0-9]*:[0-9]*:[0-9-]*:[0-9-]*' | tail -n 1
  done | awk -F'[=:]' -v sw="${YK_SRC_W}" -v sh="${YK_SRC_H}" '
    NF == 5 { if ($2 > w) w = $2; if ($3 > h) h = $3; seen = 1 }
    END {
      if (!seen || w <= 0 || h <= 0 || w > sw || h > sh) { print sw, sh, 0, 0; exit }
      w = int(w / 2) * 2; h = int(h / 2) * 2
      print w, h, int((sw - w) / 4) * 2, int((sh - h) / 4) * 2
    }'
}

yk_detect_monochrome() {
  for yk_dm_fraction in 15 35 55 75 95; do
    yk_dm_seek="$(awk -v d="${YK_DURATION}" -v f="${yk_dm_fraction}" 'BEGIN { printf "%.2f", d * f / 100 }')"
    "${YK_FFMPEG}" -hide_banner -nostdin -ss "${yk_dm_seek}" -i "$1" -frames:v 10 -vf "scale=160:-2,signalstats,metadata=print:key=lavfi.signalstats.SATAVG" -an -f null - 2>&1 |
      grep -o 'SATAVG=[0-9.]*'
  done | awk -F= '{ if ($2 > top) top = $2; seen = 1 } END { print (seen && top < 3 ? "yes" : "no") }'
}

yk_loudnorm_measure() {
  yk_lm_target="I=-20:TP=-2:LRA=11"
  "${YK_FFMPEG}" -hide_banner -nostdin -i "$1" -map "0:a:${YK_AUDIO_TRACK}" \
    -af "loudnorm=${yk_lm_target}:print_format=json" -f null - 2>&1 | awk -v t="${yk_lm_target}" '
    /"input_i"/ { gsub(/[",]/, ""); i = $3 }
    /"input_tp"/ { gsub(/[",]/, ""); tp = $3 }
    /"input_lra"/ { gsub(/[",]/, ""); lra = $3 }
    /"input_thresh"/ { gsub(/[",]/, ""); th = $3 }
    END {
      if (i == "" || tp == "" || lra == "" || th == "") exit 1
      printf "loudnorm=%s:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:linear=true\n", t, i, tp, lra, th
    }'
}

yk_scene_snap() {
  yk_ss_from="$(awk -v b="$2" -v w="$3" 'BEGIN { v = b - w; printf "%.3f", (v < 0 ? 0 : v) }')"
  "${YK_FFMPEG}" -hide_banner -nostdin -loglevel info -ss "${yk_ss_from}" -copyts -t "$(($3 * 2))" -i "$1" -vf "select='gt(scene,0.3)',showinfo" -an -f null - 2>&1 |
    sed -n 's/.*pts_time:\([0-9.]*\).*/\1/p' | awk -v b="$2" -v w="$3" '
      {
        d = $1 - b
        if (d < 0) d = -d
        if (d <= w && (best == "" || d < bestd)) { best = $1; bestd = d }
      }
      END { if (best != "") printf "%.3f\n", best }'
}
