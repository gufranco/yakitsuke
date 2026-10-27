#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

yk_inner_geometry() {
  yk_ig_box="$(awk -v pw="${YK_PIC_W}" -v ph="${YK_PIC_H}" -v cw="${YK_CANVAS_W}" -v ch="${YK_CANVAS_H}" -v rh="${YK_RASTER_H}" '
    function even(v) { v = int(v / 2 + 0.5) * 2; return (v < 2 ? 2 : v) }
    BEGIN {
      w = even(352 * pw / cw); h = even(rh * ph / ch)
      printf "%d %d %d %d\n", w, h, int((352 - w) / 4) * 2, int((rh - h) / 4) * 2
    }')"
  read -r YK_INNER_W YK_INNER_H YK_RPAD_X YK_RPAD_Y <<EOF
${yk_ig_box}
EOF
}

yk_join() {
  printf '%s\n' "$@" | awk 'NF { out = out (n++ ? "," : "") $0 } END { print out }'
}

yk_video_pre() {
  case "${YK_FIELD_MODE}" in
  ivtc) printf 'fieldmatch\ndecimate\n' ;;
  on) printf 'bwdif=mode=0:parity=-1:deint=0\n' ;;
  *) ;;
  esac
  if yk_bordered; then
    printf 'crop=%s:%s:%s:%s\n' "${YK_ACTIVE_W}" "${YK_ACTIVE_H}" "${YK_BORDER_X}" "${YK_BORDER_Y}"
  fi
  [ "${YK_SPEED}" = 1 ] || printf 'setpts=PTS/%s\n' "${YK_SPEED}"
  printf 'fps=%s\n' "${YK_FPS}"
  [ "${YK_DENOISE}" = off ] || printf 'fftdnoiz=sigma=%s\n' "${YK_DENOISE}"
  if [ "${YK_FIT}" = crop ]; then
    printf 'crop=%s:%s:%s:%s\n' "${YK_CROP_W}" "${YK_CROP_H}" "${YK_CROP_X}" "${YK_CROP_Y}"
  fi
}

yk_matrix_in() {
  case "${YK_SRC_MATRIX}" in
  '' | unknown | N/A)
    if [ "${YK_SRC_H}" -ge 720 ]; then printf 'bt709\n'; else printf '%s\n' "${YK_MATRIX_OUT}"; fi
    ;;
  *) printf '%s\n' "${YK_SRC_MATRIX}" ;;
  esac
}

yk_video_scale() {
  yk_vs_in="$(yk_matrix_in)"
  if [ "${YK_ZSCALE}" = yes ]; then
    printf 'setparams=color_primaries=%s:color_trc=bt709:colorspace=%s:range=tv\nformat=yuv444p16\n' "${yk_vs_in}" "${yk_vs_in}"
  fi
  printf 'scale=%s:%s:flags=lanczos+accurate_rnd+full_chroma_int\n' "${YK_INNER_W}" "${YK_INNER_H}"
  if [ "${YK_ZSCALE}" = yes ] && [ "${YK_COLOR_CONVERT}" = yes ] && [ "${yk_vs_in}" != "${YK_MATRIX_OUT}" ]; then
    printf 'zscale=t=bt709:m=%s:p=%s:r=tv\n' "${YK_MATRIX_OUT}" "${YK_MATRIX_OUT}"
  fi
  [ "${YK_SHARPEN}" = no ] || printf 'unsharp=5:5:0.4:5:5:0.0\n'
  if [ "${YK_INNER_W}" -ne 352 ] || [ "${YK_INNER_H}" -ne "${YK_RASTER_H}" ]; then
    printf 'pad=352:%s:%s:%s:color=black\n' "${YK_RASTER_H}" "${YK_RPAD_X}" "${YK_RPAD_Y}"
  fi
}

yk_video_finish() {
  [ "${YK_ZSCALE}" = no ] || printf 'zscale=c=center:d=error_diffusion\n'
  printf 'format=yuv420p\nsetsar=1\n'
}

yk_subtitle_layer() {
  yk_sl_style=""
  [ -z "${YK_SUB_STYLE}" ] || yk_sl_style=":force_style='${YK_SUB_STYLE}'"
  printf 'color=c=black@0:s=%sx%s:r=%s:d=%s,format=rgba,subtitles=filename=subtitles.ass:fontsdir=fonts:alpha=1%s,scale=352:%s:flags=lanczos,format=yuva444p' \
    "${YK_CANVAS_W}" "${YK_CANVAS_H}" "${YK_FPS}" "$1" "${yk_sl_style}" "${YK_RASTER_H}"
}

yk_filter_graph() {
  yk_fg_pre="$(yk_video_pre)"
  yk_fg_scale="$(yk_video_scale)"
  yk_fg_tail="$(yk_video_finish)"
  yk_fg_pic="$(yk_join "${yk_fg_pre}" "${yk_fg_scale}")"
  yk_fg_end="$(yk_join "${yk_fg_tail}")"
  if [ -z "${YK_SUB_MASTER}" ]; then
    printf '[0:v:0]%s,%s[v]\n' "${yk_fg_pic}" "${yk_fg_end}"
    return 0
  fi
  yk_fg_layer="$(yk_subtitle_layer "$1")"
  printf '[0:v:0]%s,format=yuv444p10[pic];%s[sub];[pic][sub]overlay=format=yuv444p10:eof_action=pass,%s[v]\n' \
    "${yk_fg_pic}" "${yk_fg_layer}" "${yk_fg_end}"
}

yk_audio_chain() {
  [ "${YK_SPEED}" = 1 ] || printf 'atempo=%s\n' "${YK_SPEED}"
  [ -z "${YK_LOUDNORM}" ] || printf '%s\n' "${YK_LOUDNORM}"
  printf 'aresample=44100:resampler=soxr:precision=28:dither_method=triangular_hp\n'
  printf 'aformat=sample_fmts=s16:channel_layouts=stereo\n'
}

yk_resolve_encoder() {
  case "${YK_ENCODER}" in
  ffmpeg) printf 'ffmpeg\n' ;;
  mpeg2enc)
    if yk_cmd_exists mpeg2enc && yk_cmd_exists mplex; then printf 'mpeg2enc\n'; else return 1; fi
    ;;
  *)
    if yk_cmd_exists mpeg2enc && yk_cmd_exists mplex; then printf 'mpeg2enc\n'; else printf 'ffmpeg\n'; fi
    ;;
  esac
}

yk_ffmpeg_disc() {
  yk_fd_mode="$1"
  yk_fd_out="${4:-}"
  yk_fd_span="$(yk_calc "$3 * ${YK_SPEED}")"
  yk_fd_seek="$(yk_calc "$2 * ${YK_SPEED}")"
  yk_fd_map="0:a:${YK_AUDIO_TRACK}"
  set -- -hide_banner -nostdin -v error -stats -progress progress.txt -y -ss "${yk_fd_seek}" -t "${yk_fd_span}" -i "${YK_INPUT}"
  if [ "${YK_HAS_AUDIO}" = no ]; then
    set -- "$@" -f lavfi -t "${yk_fd_span}" -i anullsrc=channel_layout=stereo:sample_rate=44100
    yk_fd_map="1:a:0"
  fi
  set -- "$@" -filter_complex "${YK_GRAPH}" -map '[v]'
  if [ "${yk_fd_mode}" = y4m ]; then
    set -- "$@" -f yuv4mpegpipe -strict -1 - -map "${yk_fd_map}" -af "${YK_AUDIO_FILTER}" \
      -c:a mp2 -b:a 224k -ar 44100 -ac 2 -f mp2 audio.mp2
  else
    set -- "$@" -map "${yk_fd_map}" -af "${YK_AUDIO_FILTER}" -c:v mpeg1video -b:v 1150k -minrate 1150k \
      -maxrate 1150k -bufsize 327680 -g "${YK_GOP}" -bf 2 -mbd rd -cmp satd -subcmp satd -trellis 2 -dia_size 3 \
      -mpv_flags +naq+qp_rd+cbp_rd -aspect 4:3 -pix_fmt yuv420p -c:a mp2 -b:a 224k -ar 44100 -ac 2 \
      -f vcd -muxrate 1411200 -packetsize 2324 "${yk_fd_out}"
  fi
  "${YK_FFMPEG}" "$@"
}

yk_encode_with_mpeg2enc() {
  rm -f "${YK_WORK}/ffmpeg.status"
  (
    cd "${YK_WORK}" || exit 1
    {
      yk_ffmpeg_disc y4m "$1" "$2"
      printf '%s\n' "$?" >ffmpeg.status
    } | mpeg2enc -v 0 -f 1 -b 1152 -a 2 -F "${YK_RATE_CODE}" -n "${YK_NORM}" -K tmpgenc -r 16 -4 1 -2 1 -E -10 -o video.m1v
  ) 2>"${YK_WORK}/encode.log" || return 1
  yk_em_status="$(cat "${YK_WORK}/ffmpeg.status" 2>/dev/null || true)"
  [ "${yk_em_status}" = 0 ] || return 1
  if ! mplex -f 1 -o "$3" "${YK_WORK}/video.m1v" "${YK_WORK}/audio.mp2" 2>"${YK_WORK}/mplex.log"; then
    if [ ! -s "$3" ]; then
      yk_error "mplex failed."
      yk_detail "${YK_WORK}/mplex.log"
      return 2
    fi
    yk_warning "mplex reported a buffer margin warning; the stream is checked next."
  fi
  rm -f "${YK_WORK}/video.m1v" "${YK_WORK}/audio.mp2"
}

yk_progress_fields() {
  awk -F= -v span="$1" '
    /^out_time_us=/ { t = $2 / 1000000 }
    /^speed=/ { v = $2; sub(/x$/, "", v); s = v + 0 }
    END {
      if (t == "") exit 1
      p = (span > 0) ? int(t * 100 / span) : 0
      if (p > 100) p = 100
      left = (s > 0 && span > t) ? int((span - t) / s) : 0
      printf "%d %.1fx %d\n", p, s, left
    }' "${YK_WORK}/progress.txt" 2>/dev/null
}

yk_progress_show() {
  yk_po_fields="$(yk_progress_fields "$1")" || return 0
  read -r yk_po_pct yk_po_rate yk_po_left <<EOF
${yk_po_fields}
EOF
  [ "$2" = final ] && yk_po_pct=100 && yk_po_left=0
  yk_po_line="$(printf '%s %3d%%  %s  %dm%02ds left' "${YK_PROGRESS_LABEL}" "${yk_po_pct}" "${yk_po_rate}" $((yk_po_left / 60)) $((yk_po_left % 60)))"
  if [ -t 2 ]; then
    printf '\r%s   ' "${yk_po_line}" >&2
    [ "$2" = final ] && printf '\n' >&2
    return 0
  fi
  yk_po_step=$((yk_po_pct / 10))
  if [ "$2" = final ] || { [ "${yk_po_pct}" -lt 100 ] && [ "${yk_po_step}" -gt "${YK_PROGRESS_STEP}" ]; }; then
    YK_PROGRESS_STEP="${yk_po_step}"
    yk_info "${yk_po_line}"
  fi
  return 0
}

yk_progress_watch() {
  yk_pw_rounds=0
  while [ -e "${YK_WORK}/encoding" ] && [ "${yk_pw_rounds}" -lt "${YK_PROGRESS_ROUNDS}" ]; do
    sleep 1
    yk_pw_rounds=$((yk_pw_rounds + 1))
    [ -e "${YK_WORK}/encoding" ] && yk_progress_show "$1" tick
  done
  return 0
}

yk_encode_disc() {
  rm -f "${YK_WORK}/progress.txt"
  : >"${YK_WORK}/encoding"
  YK_PROGRESS_STEP=0
  yk_progress_watch "$2" &
  yk_ed_watcher="$!"
  yk_ed_status=0
  yk_encode_run "$@" || yk_ed_status=1
  rm -f "${YK_WORK}/encoding"
  wait "${yk_ed_watcher}" 2>/dev/null
  [ "${yk_ed_status}" -eq 0 ] && yk_progress_show "$2" final
  return "${yk_ed_status}"
}

yk_encode_run() {
  YK_GRAPH="$(yk_filter_graph "$2")"
  yk_ed_audio="$(yk_audio_chain)"
  YK_AUDIO_FILTER="$(yk_join "${yk_ed_audio}")"
  if [ "${YK_ENCODER}" = mpeg2enc ]; then
    yk_encode_with_mpeg2enc "$1" "$2" "$3"
    yk_ed_status="$?"
    [ "${yk_ed_status}" -eq 2 ] && return 1
    [ "${yk_ed_status}" -eq 0 ] && return 0
  elif (cd "${YK_WORK}" && yk_ffmpeg_disc mpg "$1" "$2" "$3") 2>"${YK_WORK}/encode.log"; then
    return 0
  fi
  yk_error "encoding failed."
  yk_detail "${YK_WORK}/encode.log"
  return 1
}

yk_stream_signature() {
  for yk_sg_entry in "v:0 codec_name" "v:0 width" "v:0 height" "a:0 codec_name" "a:0 sample_rate" "a:0 channels"; do
    yk_probe_stream "${yk_sg_entry% *}" "${yk_sg_entry#* }" "$1"
  done | awk '{ out = out (NR > 1 ? " " : "") $0 } END { print out }'
}

yk_verify_stream() {
  [ -s "$1" ] || {
    yk_error "the encoder produced no data: $(basename -- "$1")"
    return 1
  }
  yk_vs_found="$(yk_stream_signature "$1")"
  yk_vs_expected="mpeg1video 352 ${YK_RASTER_H} mp2 44100 2"
  [ "${yk_vs_found}" = "${yk_vs_expected}" ] && return 0
  yk_error "the stream is not Video CD conformant: $(basename -- "$1")"
  yk_error "  expected: ${yk_vs_expected}"
  yk_error "  found:    ${yk_vs_found}"
  return 1
}
