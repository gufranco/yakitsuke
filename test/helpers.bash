#!/usr/bin/env bash

YK_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${YK_TESTS_DIR}/.." && pwd)"
YK_TEST_FFMPEG="$(command -v ffmpeg)"
for yk_candidate in "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/ffmpeg-full/bin/ffmpeg" /usr/local/opt/ffmpeg-full/bin/ffmpeg; do
  if [[ -x "${yk_candidate}" ]]; then
    YK_TEST_FFMPEG="${yk_candidate}"
    break
  fi
done
export YK_TESTS_DIR REPO_DIR YK_TEST_FFMPEG

yk_test_path() {
  if [[ -n "${SHIMS:-}" && -d "${SHIMS}" ]]; then
    printf '%s:%s\n' "${SHIMS}" "${PATH}"
  else
    printf '%s\n' "${PATH}"
  fi
}

yk_test_shim() {
  local name="$1"
  local body="$2"
  local real
  SHIMS="${SHIMS:-${WORK:?}/shims}"
  mkdir -p "${SHIMS}"
  real="$(command -v "${name}" || true)"
  printf '#!/bin/sh\n{ set +x; } 2>/dev/null\nREAL=%q\n%s\n' "${real}" "${body}" >"${SHIMS}/${name}"
  chmod +x "${SHIMS}/${name}"
  export SHIMS
}

yk_test_run() {
  local search_path
  local -a shell_words
  search_path="$(yk_test_path)"
  read -r -a shell_words <<<"${YK_SHELL:-sh}"
  PATH="${search_path}" YAKITSUKE_FFMPEG="${YAKITSUKE_FFMPEG-${YK_TEST_FFMPEG}}" \
    "${shell_words[@]}" "${REPO_DIR}/bin/yakitsuke" "$@"
}

yk_test_run_path() {
  local search_path="$1"
  local -a shell_words
  shift
  read -r -a shell_words <<<"${YK_SHELL:-sh}"
  PATH="${search_path}" "${shell_words[@]}" "${REPO_DIR}/bin/yakitsuke" "$@"
}

yk_test_call() {
  local search_path
  local -a shell_words
  search_path="$(yk_test_path)"
  read -r -a shell_words <<<"${YK_SHELL:-sh}"
  PATH="${search_path}" YAKITSUKE_FFMPEG="${YAKITSUKE_FFMPEG-${YK_TEST_FFMPEG}}" \
    "${shell_words[@]}" "${YK_TESTS_DIR}/call.sh" "$@"
}

yk_test_farm() {
  local farm="${WORK:?}/farm"
  local dir tool name excluded
  local -a dirs
  mkdir -p "${farm}"
  IFS=: read -r -a dirs <<<"${PATH}"
  for dir in "${dirs[@]}"; do
    [[ -d "${dir}" ]] || continue
    for tool in "${dir}"/*; do
      name="${tool##*/}"
      [[ -x "${tool}" && ! -e "${farm}/${name}" ]] || continue
      for excluded in "$@"; do
        [[ "${name}" == "${excluded}" ]] && continue 2
      done
      ln -s "${tool}" "${farm}/${name}"
    done
  done
  printf '%s\n' "${farm}"
}

yk_test_media() {
  local out="$1"
  local seconds="$2"
  local size="$3"
  local rate="$4"
  shift 4
  "${YK_TEST_FFMPEG}" -hide_banner -v error -y \
    -f lavfi -i "testsrc2=size=${size}:rate=${rate}:duration=${seconds}" \
    -f lavfi -i "sine=frequency=440:sample_rate=48000:duration=${seconds}" \
    "$@" -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p -c:a aac -shortest "${out}"
}

yk_test_srt() {
  local out="$1"
  local count="$2"
  local i start
  : >"${out}"
  for ((i = 0; i < count; i++)); do
    start=$((i * 2))
    printf '%d\n00:00:%02d,100 --> 00:00:%02d,900\nLinha %d com acentuação: você não.\nSegunda linha %d.\n\n' \
      "$((i + 1))" "${start}" "$((start + 1))" "$((i + 1))" "$((i + 1))" >>"${out}"
  done
}

yk_test_frame_luma() {
  local stats
  stats="$("${YK_TEST_FFMPEG}" -hide_banner -nostdin -ss "$2" -i "$1" -frames:v 1 \
    -vf "crop=$3,signalstats,metadata=print:key=lavfi.signalstats.YMAX" -f null - 2>&1)"
  sed -n '/YMAX=/{s/.*YMAX=\([0-9]*\).*/\1/p;q;}' <<<"${stats}"
}
