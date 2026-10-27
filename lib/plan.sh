#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${YK_LIB:?}/state.sh"

yk_disc_plan() {
  awk -v d="$1" -v u="$2" -v ov="$3" 'BEGIN {
    if (ov >= u) ov = 0
    if (d <= u) { printf "0.000 %.3f\n", d; exit }
    n = int((d - ov) / (u - ov))
    if (n * (u - ov) + ov < d - 0.0005) n++
    per = (d + (n - 1) * ov) / n
    for (i = 0; i < n; i++) printf "%.3f %.3f\n", i * (per - ov), per
  }'
}

yk_preview_plan() {
  awk -v d="$1" -v n="$2" 'BEGIN {
    start = d / 2
    if (start + n > d) start = (d > n) ? d - n : 0
    printf "%.3f %.3f\n", start, (d < n) ? d : n
  }'
}

yk_snap_edge() {
  yk_se_src="$(yk_calc "$2 * ${YK_SPEED}")"
  yk_se_hit="$(yk_scene_snap "$1" "${yk_se_src}" "$3")"
  [ -n "${yk_se_hit}" ] || return 1
  yk_calc "${yk_se_hit} / ${YK_SPEED}"
}

yk_snap_plan() {
  yk_sp_input="$1" yk_sp_plan="$2" yk_sp_window="$3"
  yk_sp_count="$(yk_lines "${yk_sp_plan}")"
  yk_sp_prev=0.000 yk_sp_index=0 yk_sp_moved=0 yk_sp_out=""
  while IFS=' ' read -r yk_sp_start yk_sp_span; do
    yk_sp_index=$((yk_sp_index + 1))
    [ "${yk_sp_index}" -lt "${yk_sp_count}" ] || continue
    yk_sp_edge="$(yk_calc "${yk_sp_start} + ${yk_sp_span}")"
    if yk_sp_hit="$(yk_snap_edge "${yk_sp_input}" "${yk_sp_edge}" "${yk_sp_window}")"; then
      [ "${yk_sp_hit}" != "${yk_sp_edge}" ] && yk_sp_moved=$((yk_sp_moved + 1))
      yk_sp_edge="${yk_sp_hit}"
    fi
    yk_sp_out="${yk_sp_out}$(awk -v s="${yk_sp_prev}" -v e="${yk_sp_edge}" 'BEGIN { printf "%.3f %.3f", s, e - s }')
"
    yk_sp_prev="$(awk -v e="${yk_sp_edge}" -v ov="${YK_OVERLAP}" 'BEGIN { v = e - ov; printf "%.3f", (v < 0 ? 0 : v) }')"
  done <<EOF
${yk_sp_plan}
EOF
  yk_sp_out="${yk_sp_out}$(awk -v s="${yk_sp_prev}" -v d="$4" 'BEGIN { printf "%.3f %.3f", s, d - s }')"
  if [ "${yk_sp_moved}" -eq 0 ] || ! printf '%s\n' "${yk_sp_out}" | awk -v u="${YK_USABLE}" '$2 <= 0 || $2 > u { bad = 1 } END { exit bad }'; then
    printf '%s\n' "${yk_sp_plan}"
    return 0
  fi
  printf '%s\n' "${yk_sp_out}"
}

yk_entry_local() {
  awk -v a="$1" -v s="$2" -v span="$3" -v m="$4" 'BEGIN { v = a - s; if (v > 0 && v < span - 1) printf "%.0f\n", v; else print m }'
}

yk_entry_points() {
  yk_ep_input="$1" yk_ep_span="$2" yk_ep_start="$3"
  yk_ep_marks="$(awk -v span="${yk_ep_span}" -v iv="$((YK_CHAPTERS * 60))" 'BEGIN {
    if (iv <= 0) exit
    for (t = iv; t < span - 1 && n < 495; t += iv) { print t; n++ }
  }')"
  [ -n "${yk_ep_marks}" ] || return 0
  yk_ep_n=0
  while IFS= read -r yk_ep_mark; do
    yk_ep_local="${yk_ep_mark}"
    yk_ep_at="$(yk_calc "${yk_ep_start} + ${yk_ep_mark}")"
    if [ "${YK_SCENE_SNAP}" -gt 0 ] && yk_ep_hit="$(yk_snap_edge "${yk_ep_input}" "${yk_ep_at}" "${YK_SCENE_SNAP}")"; then
      yk_ep_local="$(yk_entry_local "${yk_ep_hit}" "${yk_ep_start}" "${yk_ep_span}" "${yk_ep_mark}")"
    fi
    printf '      <entry id="entry-%03d">%s</entry>\n' "${yk_ep_n}" "${yk_ep_local}"
    yk_ep_n=$((yk_ep_n + 1))
  done <<EOF
${yk_ep_marks}
EOF
}
