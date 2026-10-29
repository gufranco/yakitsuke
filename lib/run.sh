#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

yk_run_inputs() {
  if [ ! -f "${YK_INPUT}" ]; then
    yk_error "source not found: ${YK_INPUT}"
    return 1
  fi
  if [ -n "${YK_SUBTITLES}" ] && [ ! -f "${YK_SUBTITLES}" ]; then
    yk_error "subtitle file not found: ${YK_SUBTITLES}"
    return 1
  fi
  YK_INPUT="$(yk_absolute_path "${YK_INPUT}")" || return 1
  [ -z "${YK_SUBTITLES}" ] || YK_SUBTITLES="$(yk_absolute_path "${YK_SUBTITLES}")" || return 1
  YK_STEM="$(basename -- "${YK_INPUT}")"
  YK_STEM="${YK_STEM%.*}"
  [ -n "${YK_TITLE}" ] || YK_TITLE="${YK_STEM}"
  [ -n "${YK_OUTPUT_DIR}" ] || YK_OUTPUT_DIR="$(dirname -- "${YK_INPUT}")"
  mkdir -p "${YK_OUTPUT_DIR}" || return 1
  YK_OUTPUT_DIR="$(cd -- "${YK_OUTPUT_DIR}" && pwd -P)"
}

yk_run_tools() {
  yk_rt_subs=no
  { [ -n "${YK_SUBTITLES}" ] || [ -n "${YK_SUB_TRACK}" ]; } && yk_rt_subs=yes
  if ! YK_FFMPEG="$(yk_resolve_ffmpeg "${yk_rt_subs}")"; then
    if [ "${yk_rt_subs}" = yes ]; then
      yk_error "no ffmpeg with the 'subtitles' filter was found. burning subtitles needs libass:"
      yk_error "brew install ffmpeg-full, or point YAKITSUKE_FFMPEG at a suitable build."
    else
      yk_error "ffmpeg is not installed. run '${YK_PROG} doctor' for what is missing."
    fi
    return 1
  fi
  YK_FFPROBE="$(yk_resolve_ffprobe)" || {
    yk_error "ffprobe is not installed."
    return 1
  }
  YK_ENCODER="$(yk_resolve_encoder)" || {
    yk_error "--encoder mpeg2enc needs mpeg2enc and mplex from mjpegtools."
    return 1
  }
  for yk_rt_tool in vcdxbuild awk sed iconv file; do
    yk_cmd_exists "${yk_rt_tool}" && continue
    yk_error "missing tool: ${yk_rt_tool}. run '${YK_PROG} doctor' for how to install it."
    return 1
  done
  YK_ZSCALE=no
  yk_has_filter "${YK_FFMPEG}" zscale && YK_ZSCALE=yes
  return 0
}

yk_run_probe() {
  YK_DURATION="$(yk_probe_duration "${YK_INPUT}")" || {
    yk_error "could not read a usable duration from $(basename -- "${YK_INPUT}")"
    return 1
  }
  YK_SRC_W="$(yk_probe_stream v:0 width "${YK_INPUT}")"
  YK_SRC_H="$(yk_probe_stream v:0 height "${YK_INPUT}")"
  if ! yk_is_uint "${YK_SRC_W}" || ! yk_is_uint "${YK_SRC_H}"; then
    yk_error "the source has no readable video stream: $(basename -- "${YK_INPUT}")"
    return 1
  fi
  YK_SRC_SAR="$(yk_probe_stream v:0 sample_aspect_ratio "${YK_INPUT}")"
  YK_SRC_FPS="$(yk_probe_stream v:0 r_frame_rate "${YK_INPUT}")"
  YK_SRC_MATRIX="$(yk_probe_stream v:0 color_space "${YK_INPUT}")"
  YK_TRACKS="$(yk_track_list "${YK_INPUT}")"
  YK_HAS_AUDIO=yes
  yk_pr_audio="$(yk_probe_stream "a:${YK_AUDIO_TRACK}" codec_name "${YK_INPUT}")"
  [ -n "${yk_pr_audio}" ] || YK_HAS_AUDIO=no
}

yk_run_analyse() {
  yk_choose_standard
  yk_geometry "${YK_INPUT}"
  yk_inner_geometry
  YK_FIELD_MODE="${YK_DEINTERLACE}"
  [ "${YK_DEINTERLACE}" = auto ] && YK_FIELD_MODE="$(yk_detect_field_mode "${YK_INPUT}")"
  YK_MONOCHROME=no
  if [ "${YK_SUB_COLOR}" = auto ] && { [ -n "${YK_SUBTITLES}" ] || [ -n "${YK_SUB_TRACK}" ]; }; then
    YK_MONOCHROME="$(yk_detect_monochrome "${YK_INPUT}")"
  fi
  return 0
}

yk_run_plan() {
  YK_CAPACITY=$((YK_DISC_MINUTES * 60 * 75))
  YK_USABLE="$(awk -v c="${YK_CAPACITY}" 'BEGIN { printf "%.3f", (c - 1200) / 75 }')"
  yk_rp_length="$(yk_calc "${YK_DURATION} / ${YK_SPEED}")"
  if [ "${YK_PREVIEW}" -gt 0 ]; then
    YK_PLAN="$(yk_preview_plan "${yk_rp_length}" "${YK_PREVIEW}")"
    YK_TOTAL=1
    YK_STEM="${YK_STEM}_preview"
    return 0
  fi
  YK_PLAN="$(yk_disc_plan "${yk_rp_length}" "${YK_USABLE}" "${YK_OVERLAP}")"
  YK_TOTAL="$(yk_lines "${YK_PLAN}")"
  if [ "${YK_SCENE_SNAP}" -gt 0 ] && [ "${YK_TOTAL}" -gt 1 ]; then
    yk_rp_snapped="$(yk_snap_plan "${YK_INPUT}" "${YK_PLAN}" "${YK_SCENE_SNAP}" "${yk_rp_length}")"
    if [ "${yk_rp_snapped}" != "${YK_PLAN}" ]; then
      YK_PLAN="${yk_rp_snapped}"
      YK_SNAPPED=yes
    fi
  fi
  return 0
}

yk_run_report() {
  [ "${YK_JSON}" = no ] || return 0
  printf '\n'
  yk_info "Source: $(basename -- "${YK_INPUT}")"
  yk_rr_aspect="$(awk -v d="${YK_DAR}" 'BEGIN { printf "%.3f", d }')"
  yk_rr_clock="$(yk_clock "${YK_DURATION}")"
  yk_info "        ${YK_SRC_W}x${YK_SRC_H}, ${yk_rr_aspect} display aspect, ${yk_rr_clock}"
  yk_bordered && yk_info "        black bars stripped, active picture ${YK_ACTIVE_W}x${YK_ACTIVE_H} at +${YK_BORDER_X}+${YK_BORDER_Y}"
  yk_rr_name="$(printf '%s' "${YK_STANDARD}" | tr '[:lower:]' '[:upper:]')"
  yk_info "Target: ${yk_rr_name} Video CD, 352x${YK_RASTER_H} at ${YK_FPS} fps"
  [ "${YK_SPEED}" = 1 ] || yk_info "        film sped up to 25 fps, ${YK_SPEED}x, pitch kept"
  yk_info "        picture ${YK_INNER_W}x${YK_INNER_H} at +${YK_RPAD_X}+${YK_RPAD_Y}, ${YK_FIT}"
  yk_info "        deinterlace ${YK_FIELD_MODE}, denoise ${YK_DENOISE}, sharpen ${YK_SHARPEN}"
  if [ "${YK_HAS_AUDIO}" = yes ]; then yk_info "        audio track ${YK_AUDIO_TRACK}"; else yk_info "        audio silent, the source has none"; fi
  [ -z "${YK_TRACKS}" ] || printf '%s\n' "${YK_TRACKS}" | while IFS= read -r yk_rr_line; do yk_info "        ${yk_rr_line}"; done
  if [ -n "${YK_SUB_MASTER}" ]; then
    yk_rr_subs="$(yk_run_sub_summary)"
    yk_info "        subtitles burned in: ${yk_rr_subs}"
  fi
  yk_info "Media:  ${YK_DISC_MINUTES} min, ${YK_CAPACITY} sectors, ${YK_USABLE}s usable per disc"
  if [ "${YK_PREVIEW}" -gt 0 ]; then
    yk_info "Plan:   preview only, one ${YK_PREVIEW}s sample from the middle, ${YK_ENCODER}"
  else
    yk_info "Plan:   ${YK_TOTAL} disc(s), ${YK_OVERLAP}s overlap, ${YK_ENCODER}"
  fi
  [ "${YK_SNAPPED:-no}" = no ] || yk_info "        seams snapped to the nearest scene change within ${YK_SCENE_SNAP}s"
  printf '\n'
  return 0
}

yk_run_sub_summary() {
  awk -F, '/^Dialogue:/ { n++; if ($4 == "Box") b++ } END {
    if (n == 0) { print "no dialogue lines"; exit }
    printf "%d lines, %d on a box, %d outlined\n", n, b, n - b
  }' "${YK_SUB_MASTER}"
}

yk_run_dry() {
  yk_rd_index=1
  while IFS=' ' read -r yk_rd_start yk_rd_span; do
    yk_rd_bin="${YK_OUTPUT_DIR}/${YK_STEM}_disc${yk_rd_index}.bin"
    yk_info "Disc ${yk_rd_index} of ${YK_TOTAL} would hold ${yk_rd_span}s from ${yk_rd_start}s: ${yk_rd_bin}"
    yk_rd_path="$(yk_json_string "${yk_rd_bin}")"
    yk_json_add "{\"number\":${yk_rd_index},\"start\":${yk_rd_start},\"seconds\":${yk_rd_span},\"bin\":${yk_rd_path}}"
    yk_rd_index=$((yk_rd_index + 1))
  done <<EOF2
${YK_PLAN}
EOF2
}

yk_json_add() {
  YK_JSON_DISCS="${YK_JSON_DISCS}${YK_JSON_DISCS:+,}$1"
}

yk_json_disc() {
  yk_jd_bin="$(yk_json_string "$2")"
  yk_jd_cue="$(yk_json_string "$3")"
  yk_json_add "{\"number\":$1,\"bin\":${yk_jd_bin},\"cue\":${yk_jd_cue},\"sectors\":${YK_IMAGE_SECTORS},\"kept\":$4}"
}

yk_json_report() {
  [ "${YK_JSON}" = yes ] || return 0
  yk_jr_source="$(yk_json_string "${YK_INPUT}")"
  yk_jr_output="$(yk_json_string "${YK_OUTPUT_DIR}")"
  yk_jr_dry=false
  [ "${YK_DRY_RUN}" = no ] || yk_jr_dry=true
  printf '{"source":%s,"output_dir":%s,"dry_run":%s,"capacity":%s,"discs":[%s]}\n' \
    "${yk_jr_source}" "${yk_jr_output}" "${yk_jr_dry}" "${YK_CAPACITY}" "${YK_JSON_DISCS}"
}

yk_run_loudness() {
  YK_LOUDNORM=""
  [ "${YK_NORMALIZE}" = yes ] || return 0
  if [ "${YK_HAS_AUDIO}" = yes ] && YK_LOUDNORM="$(yk_loudnorm_measure "${YK_INPUT}")" && [ -n "${YK_LOUDNORM}" ]; then
    yk_info "Loudness measured; applying an exact correction."
    return 0
  fi
  YK_LOUDNORM="loudnorm=I=-20:TP=-2:LRA=11"
  yk_warning "loudness measurement failed, falling back to single-pass normalisation."
}

yk_run_existing() {
  if [ "${YK_RESUME}" = yes ] && [ -s "$2" ] && [ -s "$3" ]; then
    if yk_verify_image "$2" >/dev/null 2>&1; then
      yk_info "Disc $1 of ${YK_TOTAL}: already present, keeping it."
      return 0
    fi
    yk_warning "disc $1 of ${YK_TOTAL}: the existing image is unusable, encoding it again."
    return 1
  fi
  if [ "${YK_FORCE}" != yes ] && [ "${YK_RESUME}" != yes ] && { [ -e "$2" ] || [ -e "$3" ]; }; then
    yk_error "refusing to overwrite $(basename -- "$2"); pass --force or --resume"
    return 2
  fi
  return 1
}

yk_run_disc() {
  yk_rn_mpg="${YK_WORK}/disc$1.mpg"
  yk_rn_bin="${YK_OUTPUT_DIR}/${YK_STEM}_disc$1.bin"
  yk_rn_cue="${YK_OUTPUT_DIR}/${YK_STEM}_disc$1.cue"
  yk_run_existing "$1" "${yk_rn_bin}" "${yk_rn_cue}"
  case "$?" in
  0)
    yk_json_disc "$1" "${yk_rn_bin}" "${yk_rn_cue}" true
    return 0
    ;;
  2) return 2 ;;
  *) ;;
  esac
  if [ -n "${YK_SUB_MASTER}" ]; then
    yk_subs_shift "${YK_SUB_MASTER}" "${YK_WORK}/subtitles.ass" "$2" "$3" || return 2
  fi
  yk_info "Disc $1 of ${YK_TOTAL}, encoding $3s from $2s"
  YK_PROGRESS_LABEL="Disc $1 of ${YK_TOTAL}, encoding"
  yk_encode_disc "$2" "$3" "${yk_rn_mpg}" || return 2
  yk_verify_stream "${yk_rn_mpg}" || return 2
  yk_rn_entries=""
  [ "${YK_CHAPTERS}" -eq 0 ] || yk_rn_entries="$(yk_entry_points "${YK_INPUT}" "$3" "$2")"
  yk_build_image "$1" "${yk_rn_mpg}" "${yk_rn_bin}" "${yk_rn_cue}" "${yk_rn_entries}" || return "$?"
  [ "${YK_KEEP_MPEG}" = no ] || mv -f "${yk_rn_mpg}" "${YK_OUTPUT_DIR}/${YK_STEM}_disc$1.mpg"
  yk_info "Disc $1 of ${YK_TOTAL}: $(basename -- "${yk_rn_bin}"), ${YK_IMAGE_SECTORS} of ${YK_CAPACITY} sectors, $((YK_IMAGE_SECTORS * 100 / YK_CAPACITY))% full"
  yk_json_disc "$1" "${yk_rn_bin}" "${yk_rn_cue}" false
}

yk_run_discs() {
  yk_rs_index=1 yk_rs_full=0
  while IFS=' ' read -r yk_rs_start yk_rs_span; do
    yk_run_disc "${yk_rs_index}" "${yk_rs_start}" "${yk_rs_span}"
    case "$?" in
    0) ;;
    1) yk_rs_full=$((yk_rs_full + 1)) ;;
    *) return 1 ;;
    esac
    yk_rs_index=$((yk_rs_index + 1))
  done <<EOF2
${YK_PLAN}
EOF2
  if [ "${yk_rs_full}" -gt 0 ]; then
    yk_error "${yk_rs_full} image(s) do not fit the selected media."
    return 1
  fi
  yk_info "Wrote ${YK_TOTAL} Video CD image(s) to ${YK_OUTPUT_DIR}."
  yk_json_report
}

yk_run() {
  yk_run_inputs || return 1
  yk_run_tools || return 1
  yk_run_probe || return 1
  yk_run_analyse
  yk_subs_prepare || return 1
  yk_run_plan
  yk_run_report
  if [ "${YK_DRY_RUN}" = yes ]; then
    yk_run_dry
    yk_json_report
    return 0
  fi
  mkdir -p "${YK_WORK}/fonts" && cp -f "${YK_SHARE}/fonts/"*.ttf "${YK_WORK}/fonts/" || return 1
  yk_run_loudness
  yk_run_discs
}
