#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

YK_SUB_FONT="Atkinson Hyperlegible"
YK_SUB_BOX_YHIGH=119
YK_SUB_BOX_EDGE=20

yk_ensure_utf8() {
  yk_eu_enc="$(file -b --mime-encoding "$1" 2>/dev/null)"
  yk_eu_bom="$(printf '\357\273\277')"
  case "${yk_eu_enc}" in
  utf-8 | us-ascii)
    sed "1s/^${yk_eu_bom}//" "$1" >"$1.tmp" && mv -f "$1.tmp" "$1"
    return 0
    ;;
  '')
    yk_error "could not tell the text encoding of $(basename -- "$1")"
    return 1
    ;;
  *) ;;
  esac
  for yk_eu_try in "${yk_eu_enc}" windows-1252 iso-8859-1; do
    if iconv -f "${yk_eu_try}" -t utf-8 "$1" >"$1.tmp" 2>/dev/null && [ -s "$1.tmp" ]; then
      mv -f "$1.tmp" "$1"
      yk_info "Subtitles converted from ${yk_eu_try} to UTF-8."
      return 0
    fi
  done
  rm -f "$1.tmp"
  yk_error "could not convert $(basename -- "$1") to UTF-8"
  return 1
}

yk_subs_codec_kind() {
  case "$1" in
  dvd_subtitle | hdmv_pgs_subtitle | dvb_subtitle | xsub) printf 'bitmap\n' ;;
  ass | ssa) printf 'styled\n' ;;
  *) printf 'text\n' ;;
  esac
}

yk_subs_source() {
  YK_SUB_KIND=text
  if [ -n "${YK_SUB_TRACK}" ]; then
    yk_ss_codec="$(yk_probe_stream "s:${YK_SUB_TRACK}" codec_name "${YK_INPUT}")"
    YK_SUB_KIND="$(yk_subs_codec_kind "${yk_ss_codec}")"
    if [ "${YK_SUB_KIND}" = bitmap ]; then
      yk_error "subtitle stream ${YK_SUB_TRACK} is a picture, not text. run it through OCR first,"
      yk_error "for example Subtitle Edit or vobsub2srt, then pass the .srt file."
      return 1
    fi
    "${YK_FFMPEG}" -hide_banner -nostdin -v error -y -i "${YK_INPUT}" -map "0:s:${YK_SUB_TRACK}" \
      -c:s ass "${YK_WORK}/source.ass" 2>/dev/null && return 0
    yk_error "could not extract subtitle stream ${YK_SUB_TRACK} as text."
    return 1
  fi
  cp -f -- "${YK_SUBTITLES}" "${YK_WORK}/source.sub" && yk_ensure_utf8 "${YK_WORK}/source.sub" || return 1
  case "${YK_SUBTITLES}" in
  *.ass | *.ssa | *.ASS | *.SSA)
    mv -f "${YK_WORK}/source.sub" "${YK_WORK}/source.ass"
    YK_SUB_KIND=styled
    ;;
  *) ;;
  esac
  return 0
}

yk_subs_play() {
  YK_PLAY_H="${YK_RASTER_H}"
  YK_PLAY_W=$((YK_RASTER_H * 4 / 3))
  yk_sp_sizes="$(awk -v ph="${YK_PIC_H}" -v py="${YK_PAD_Y}" -v ch="${YK_CANVAS_H}" -v h="${YK_PLAY_H}" 'BEGIN {
    bar = (ch - ph - py) * h / ch
    printf "%.2f %d\n", h * 0.075, int(h * (bar > h * 0.05 ? 0.08 : 0.10) + 0.5)
  }')"
  read -r YK_SUB_SIZE YK_SUB_MARGIN_V <<EOF
${yk_sp_sizes}
EOF
}

yk_subs_fill() {
  case "${YK_SUB_COLOR}" in
  white) YK_SUB_FILL="&H00FFFFFF" ;;
  yellow) YK_SUB_FILL="&H0000FFFF" ;;
  *)
    if [ "${YK_MONOCHROME}" = yes ]; then
      YK_SUB_FILL="&H0000FFFF"
    else
      YK_SUB_FILL="&H00FFFFFF"
    fi
    ;;
  esac
}

yk_subs_styles() {
  awk -v fs="${YK_SUB_SIZE}" -v fill="${YK_SUB_FILL}" -v font="${YK_SUB_FONT}" \
    -v pw="${YK_PLAY_W}" -v mv="${YK_SUB_MARGIN_V}" 'BEGIN {
    mh = int(pw * 0.05 + 0.5)
    printf "Style: Outline,%s,%s,%s,&H000000FF,&H00000000,&HA0000000,0,0,0,0,100,100,0,0,1,%.2f,%.2f,2,%d,%d,%d,1\n",
      font, fs, fill, fs * 0.145, fs * 0.078, mh, mh, mv
    printf "Style: Box,%s,%s,%s,&H000000FF,&H26000000,&HFF000000,0,0,0,0,100,100,0,0,3,%.2f,0,2,%d,%d,%d,1\n",
      font, fs, fill, fs * 0.22, mh, mh, mv
  }'
}

yk_subs_restyle() {
  yk_rs_styles="$(yk_subs_styles)"
  YK_STYLES="${yk_rs_styles}" awk -v pw="${YK_PLAY_W}" -v ph="${YK_PLAY_H}" '
    /^PlayResX:/ { print "PlayResX: " pw; x = 1; next }
    /^PlayResY:/ { print "PlayResY: " ph; y = 1; next }
    /^ScaledBorderAndShadow:/ { print "ScaledBorderAndShadow: yes"; print "WrapStyle: 0"; s = 1; next }
    /^WrapStyle:/ { next }
    /^Style: / { if (!done) print ENVIRON["YK_STYLES"]; done = 1; next }
    { print }
    END { exit !(x && y && s && done) }' "$1" >"$2"
}

yk_subs_zone() {
  awk -v ph="${YK_PLAY_H}" -v mv="${YK_SUB_MARGIN_V}" -v fs="${YK_SUB_SIZE}" -v ch="${YK_CANVAS_H}" \
    -v py="${YK_PAD_Y}" -v pich="${YK_PIC_H}" -v fit="${YK_FIT}" \
    -v bx="${YK_BORDER_X}" -v by="${YK_BORDER_Y}" -v aw="${YK_ACTIVE_W}" -v ah="${YK_ACTIVE_H}" \
    -v cx="${YK_CROP_X}" -v cy="${YK_CROP_Y}" -v cw="${YK_CROP_W}" -v crh="${YK_CROP_H}" '
    function even(v) { v = int(v / 2) * 2; return (v < 2 ? 2 : v) }
    BEGIN {
      k = ch / ph
      y2 = ch - mv * k
      y1 = y2 - fs * 2.94 * k
      top = (y1 > py) ? y1 : py
      bottom = (y2 < py + pich) ? y2 : py + pich
      if (bottom - top < 2) { print "none"; exit }
      w = (fit == "crop") ? cw : aw
      h = (fit == "crop") ? crh : ah
      x0 = bx + (fit == "crop" ? cx : 0)
      y0 = by + (fit == "crop" ? cy : 0)
      zy = y0 + (top - py) / pich * h
      zh = (bottom - top) / pich * h
      printf "%d %d %d %d\n", even(w * 0.8), even(zh), even(x0 + w * 0.1), even(zy)
    }'
}

yk_subs_measure() {
  printf '#\n' >"${YK_WORK}/yhigh.log"
  printf '#\n' >"${YK_WORK}/edge.log"
  [ "${YK_SUB_BOX}" = auto ] || return 0
  yk_sm_zone="$(yk_subs_zone)"
  [ "${yk_sm_zone}" = none ] && return 0
  read -r yk_sm_w yk_sm_h yk_sm_x yk_sm_y <<ZONE
${yk_sm_zone}
ZONE
  yk_info "Measuring the picture under each subtitle."
  yk_sm_graph="[0:v:0]crop=${yk_sm_w}:${yk_sm_h}:${yk_sm_x}:${yk_sm_y},scale=192:24,fps=2,split[a][b];[a]signalstats,metadata=mode=print:key=lavfi.signalstats.YHIGH:file=yhigh.txt[x];[b]edgedetect=low=0.08:high=0.2,signalstats,metadata=mode=print:key=lavfi.signalstats.YAVG:file=edge.txt[y]"
  (cd "${YK_WORK}" && "${YK_FFMPEG}" -hide_banner -nostdin -v error -i "${YK_INPUT}" -an -sn -filter_complex "${yk_sm_graph}" -map '[x]' -f null - -map '[y]' -f null -) 2>"${YK_WORK}/measure.log" || {
    yk_warning "could not measure the picture under the subtitles; every line gets an outline."
    return 0
  }
  cat "${YK_WORK}/yhigh.txt" >>"${YK_WORK}/yhigh.log"
  cat "${YK_WORK}/edge.txt" >>"${YK_WORK}/edge.log"
}

yk_subs_assign() {
  awk -v mode="${YK_SUB_BOX}" -v offset="${YK_SUB_OFFSET}" -v fs="${YK_SUB_SIZE}" \
    -v pw="${YK_PLAY_W}" -v yhigh_limit="${YK_SUB_BOX_YHIGH}" -v edge_limit="${YK_SUB_BOX_EDGE}" \
    -f "${YK_LIB}/assign.awk" "${YK_SHARE}/fonts/widths.txt" "${YK_WORK}/yhigh.log" "${YK_WORK}/edge.log" "$1" >"$2"
}

yk_subs_prepare() {
  YK_SUB_MASTER=""
  [ -n "${YK_SUBTITLES}" ] || [ -n "${YK_SUB_TRACK}" ] || return 0
  yk_subs_source || return 1
  YK_SUB_MASTER="${YK_WORK}/master.ass"
  if [ "${YK_SUB_KIND}" = styled ]; then
    cp -f "${YK_WORK}/source.ass" "${YK_SUB_MASTER}"
    return 0
  fi
  if [ -z "${YK_SUB_TRACK}" ] && ! "${YK_FFMPEG}" -hide_banner -nostdin -v error -y -i "${YK_WORK}/source.sub" "${YK_WORK}/source.ass" 2>/dev/null; then
    yk_error "could not read the subtitle file as text: $(basename -- "${YK_SUBTITLES}")"
    return 1
  fi
  yk_subs_play
  yk_subs_fill
  yk_subs_restyle "${YK_WORK}/source.ass" "${YK_WORK}/styled.ass" ||
    yk_warning "the subtitle script had no PlayRes header; sizes may drift."
  yk_subs_measure
  yk_subs_assign "${YK_WORK}/styled.ass" "${YK_SUB_MASTER}"
}

yk_subs_shift() {
  awk -v off="${YK_SUB_OFFSET}" -v start="$3" -v span="$4" -v speed="${YK_SPEED}" '
    function seconds(t, p) { split(t, p, ":"); return p[1] * 3600 + p[2] * 60 + p[3] }
    function stamp(v, h, m) {
      if (v < 0) v = 0
      h = int(v / 3600); v -= h * 3600
      m = int(v / 60); v -= m * 60
      return sprintf("%d:%02d:%05.2f", h, m, v)
    }
    /^Dialogue:/ {
      n = split($0, f, ",")
      a = (seconds(f[2]) + off) / speed - start
      b = (seconds(f[3]) + off) / speed - start
      if (b <= 0 || a >= span) next
      f[2] = stamp(a)
      f[3] = stamp(b)
      out = f[1]
      for (i = 2; i <= n; i++) out = out "," f[i]
      print out
      next
    }
    { print }' "$1" >"$2"
}
