#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

yk_flat() {
  "${YK_TEST_FFMPEG}" -hide_banner -v error -y -f lavfi -i "color=c=$2:s=$3:r=25:d=6" \
    -f lavfi -i "sine=frequency=440:sample_rate=48000:duration=6" \
    -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p -c:a aac -shortest "$1"
}

setup_file() {
  local dir="${BATS_FILE_TMPDIR:?}"
  yk_flat "${dir}/white.mp4" 0xF0F0F0 640x480
  yk_flat "${dir}/black.mp4" 0x10182C 640x480
  yk_flat "${dir}/wide.mp4" 0xF0F0F0 1280x320
  yk_test_media "${dir}/mono.mp4" 6 640x480 25 -vf "hue=s=0"
  yk_test_srt "${dir}/two.srt" 2
  "${YK_TEST_FFMPEG}" -hide_banner -v error -y -i "${dir}/black.mp4" -i "${dir}/two.srt" \
    -map 0 -map 1 -c copy -c:s srt "${dir}/embedded.mkv"
  "${YK_TEST_FFMPEG}" -hide_banner -v error -y -i "${dir}/two.srt" "${dir}/styled.ass"
  "${YK_TEST_FFMPEG}" -hide_banner -v error -y -i "${dir}/black.mp4" -i "${dir}/styled.ass" \
    -map 0 -map 1 -c copy -c:s ass "${dir}/embedded-ass.mkv"
}

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/yk-subs.XXXXXX")"
}

teardown() {
  rm -rf "${WORK}"
}

yk_styles() {
  awk -F, '/^Dialogue:/ { n[$4]++ } END { if (n["Box"]) printf "Box=%d ", n["Box"]; if (n["Outline"]) printf "Outline=%d ", n["Outline"] }' <<<"$1"
}

@test "lines over a bright picture get a background box" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/white.mp4"

  # Act
  run yk_test_call call_subs "${clip}" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  [[ "${status}" -eq 0 ]]
  local styles
  styles="$(yk_styles "${output}")"
  [[ "${styles}" == "Box=2 " ]]
}

@test "lines over a dark picture get an outline" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/black.mp4"

  # Act
  run yk_test_call call_subs "${clip}" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  local styles
  styles="$(yk_styles "${output}")"
  [[ "${styles}" == "Outline=2 " ]]
}

@test "lines that sit in a letterbox bar are not measured and get an outline" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/wide.mp4"

  # Act
  run yk_test_call call_subs "${clip}" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  local styles
  styles="$(yk_styles "${output}")"
  [[ "${styles}" == "Outline=2 " ]]
}

@test "--sub-box always boxes every line" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/black.mp4"

  # Act
  YK_SUB_BOX=always run yk_test_call call_subs "${clip}" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  local styles
  styles="$(yk_styles "${output}")"
  [[ "${styles}" == "Box=2 " ]]
}

@test "--sub-box never outlines every line" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/white.mp4"

  # Act
  YK_SUB_BOX=never run yk_test_call call_subs "${clip}" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  local styles
  styles="$(yk_styles "${output}")"
  [[ "${styles}" == "Outline=2 " ]]
}

@test "subtitles are white by default" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/black.mp4"

  # Act
  run yk_test_call call_subs "${clip}" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  [[ "${output}" == *"Style: Outline,Atkinson Hyperlegible,21.60,&H00FFFFFF,"* ]]
}

@test "subtitles on a black and white film are yellow" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/mono.mp4"

  # Act
  run yk_test_call call_subs "${clip}" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  [[ "${output}" == *"Style: Box,Atkinson Hyperlegible,21.60,&H0000FFFF,"* ]]
}

@test "--sub-color yellow and white override the choice" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/mono.mp4"

  # Act
  YK_SUB_COLOR=white run yk_test_call call_subs "${clip}" "${BATS_FILE_TMPDIR}/two.srt"
  local white="${output}"
  YK_SUB_COLOR=yellow run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  [[ "${white}" == *",&H00FFFFFF,&H000000FF,"* ]]
  [[ "${output}" == *",&H0000FFFF,&H000000FF,"* ]]
}

@test "a UTF-8 byte order mark is removed" {
  # Arrange
  printf '\357\273\277' >"${WORK}/bom.srt"
  cat "${BATS_FILE_TMPDIR}/two.srt" >>"${WORK}/bom.srt"

  # Act
  run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${WORK}/bom.srt"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Linha 1 com acentuação: você não."* ]]
}

@test "a Latin-1 subtitle file is converted to UTF-8" {
  # Arrange
  iconv -f utf-8 -t iso-8859-1 "${BATS_FILE_TMPDIR}/two.srt" >"${WORK}/latin.srt"

  # Act
  run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${WORK}/latin.srt"

  # Assert
  [[ "${output}" == *"Subtitles converted from iso-8859-1 to UTF-8."* ]]
  [[ "${output}" == *"Linha 2 com acentuação: você não."* ]]
}

@test "a subtitle file whose encoding cannot be told is refused" {
  # Arrange
  yk_test_shim file "exit 0"

  # Act
  run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: could not tell the text encoding of source.sub" ]]
}

@test "a subtitle file that no conversion can read is refused" {
  # Arrange
  yk_test_shim file "printf \"unknown-8bit\\n\""
  yk_test_shim iconv "exit 1"

  # Act
  run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: could not convert source.sub to UTF-8" ]]
}

@test "a styled ASS file keeps its own styles" {
  # Arrange
  local expected
  expected="$(cat "${BATS_FILE_TMPDIR}/styled.ass")"

  # Act
  run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${BATS_FILE_TMPDIR}/styled.ass"

  # Assert
  [[ "${output}" == "${expected}" ]]
}

@test "an embedded text track is extracted and restyled" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/embedded.mkv"

  # Act
  run yk_test_call call_subs "${clip}" "" 0

  # Assert
  local styles
  styles="$(yk_styles "${output}")"
  [[ "${styles}" == "Outline=2 " ]]
}

@test "an embedded styled track is kept as it is" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/embedded-ass.mkv"

  # Act
  run yk_test_call call_subs "${clip}" "" 0

  # Assert
  [[ "${output}" == *"Style: Default,"* ]]
}

@test "an embedded picture-based track is refused with the way out" {
  # Arrange
  yk_test_shim ffprobe "case \"\$*\" in *s:0*codec_name*) printf \"hdmv_pgs_subtitle\\n\"; exit 0 ;; esac
exec \"\$REAL\" \"\$@\""
  mkdir -p "${WORK}/lone"
  ln -s "${YK_TEST_FFMPEG}" "${WORK}/lone/ffmpeg"

  # Act
  YAKITSUKE_FFMPEG="${WORK}/lone/ffmpeg" run yk_test_call call_subs "${BATS_FILE_TMPDIR}/embedded.mkv" "" 0

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"subtitle stream 0 is a picture, not text. run it through OCR first,"* ]]
}

@test "a missing embedded track is reported" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/black.mp4"

  # Act
  run yk_test_call call_subs "${clip}" "" 3

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: could not extract subtitle stream 3 as text." ]]
}

@test "a subtitle file that is not text is refused" {
  # Arrange
  head -c 4096 /dev/urandom >"${WORK}/noise.srt"
  yk_test_shim file "printf \"utf-8\\n\""

  # Act
  run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${WORK}/noise.srt"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: could not read the subtitle file as text: noise.srt" ]]
}

@test "a failed measurement outlines every line and says so" {
  # Arrange
  yk_test_shim ffmpeg "case \"\$*\" in *edgedetect*) exit 1 ;; esac
exec \"\$REAL\" \"\$@\""

  # Act
  YAKITSUKE_FFMPEG="${SHIMS}/ffmpeg" run yk_test_call call_subs "${BATS_FILE_TMPDIR}/white.mp4" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  [[ "${output}" == *"could not measure the picture under the subtitles; every line gets an outline"* ]]
  local styles
  styles="$(yk_styles "${output}")"
  [[ "${styles}" == "Outline=2 " ]]
}

@test "a script without a PlayRes header is used with a warning" {
  # Arrange
  yk_test_shim ffmpeg "case \"\$*\" in *source.sub*)
  for arg; do out=\"\$arg\"; done
  printf \"[Events]\\nDialogue: 0,0:00:00.10,0:00:00.90,Default,,0,0,0,,Bare line\\n\" >\"\$out\"
  exit 0 ;;
esac
exec \"\$REAL\" \"\$@\""

  # Act
  YAKITSUKE_FFMPEG="${SHIMS}/ffmpeg" YK_SUB_BOX=never run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  [[ "${output}" == *"the subtitle script had no PlayRes header; sizes may drift"* ]]
  [[ "${output}" == *"Bare line"* ]]
}

@test "a line too wide for the screen is scaled down to fit" {
  # Arrange
  printf '1\n00:00:01,000 --> 00:00:02,000\nEsta linha tem quarenta e poucos caracteres\n' >"${WORK}/wide.srt"

  # Act
  run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${WORK}/wide.srt"

  # Assert
  [[ "${output}" =~ \{\\fscx(8[0-9]|9[0-9])\\fscy(8[0-9]|9[0-9])\}Esta ]]
}

@test "a line far too wide is scaled no smaller than 80 percent and left to wrap" {
  # Arrange
  printf '1\n00:00:01,000 --> 00:00:02,000\nUma linha absurdamente longa que nenhum padrão de legenda aceitaria jamais\n' >"${WORK}/huge.srt"

  # Act
  run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${WORK}/huge.srt"

  # Assert
  [[ "${output}" == *'{\fscx80\fscy80}Uma linha'* ]]
}

@test "a short line keeps its full size" {
  # Arrange
  printf '1\n00:00:01,000 --> 00:00:02,000\nCurta.\n' >"${WORK}/short.srt"

  # Act
  run yk_test_call call_subs "${BATS_FILE_TMPDIR}/black.mp4" "${WORK}/short.srt"

  # Assert
  [[ "${output}" == *",,Curta."* ]]
}

@test "timing is shifted per disc, sped up and clipped to the disc" {
  # Arrange
  printf '[Events]\nDialogue: 0,0:00:01.00,0:00:02.00,Outline,,0,0,0,,before, with a comma\nDialogue: 0,0:00:10.00,0:00:12.00,Box,,0,0,0,,inside\nDialogue: 0,0:01:00.00,0:01:02.00,Box,,0,0,0,,after\n' >"${WORK}/in.ass"

  # Act
  YK_SUB_OFFSET=0.5 YK_SPEED=1.25 run yk_test_call yk_subs_shift "${WORK}/in.ass" /dev/stdout 4 20

  # Assert
  [[ "${output}" == $'[Events]\nDialogue: 0,0:00:04.40,0:00:06.00,Box,,0,0,0,,inside' ]]
}
