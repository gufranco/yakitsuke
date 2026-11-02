#!/usr/bin/env bats
# shellcheck disable=SC2016

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  yk_test_media "${BATS_FILE_TMPDIR:?}/wide.mp4" 3 640x360 25
  yk_test_media "${BATS_FILE_TMPDIR:?}/square.mp4" 3 320x240 25
  yk_test_media "${BATS_FILE_TMPDIR:?}/ntsc.mp4" 3 640x360 30000/1001
  yk_test_media "${BATS_FILE_TMPDIR:?}/film.mp4" 3 640x360 24000/1001
  yk_test_media "${BATS_FILE_TMPDIR:?}/tff576.mp4" 8 720x576 50 -vf "interlace=scan=tff,setfield=tff" -flags +ildct+ilme
  yk_test_media "${BATS_FILE_TMPDIR:?}/bff576.mp4" 8 720x576 50 -vf "interlace=scan=bff,setfield=bff" -flags +ildct+ilme
  yk_test_media "${BATS_FILE_TMPDIR:?}/tff480.mp4" 8 640x480 50 -vf "interlace=scan=tff,setfield=tff" -flags +ildct+ilme
  yk_test_srt "${BATS_FILE_TMPDIR:?}/one.srt" 1
  "${YAKITSUKE_TEST_FFMPEG}" -hide_banner -v error -y -f lavfi -i "testsrc2=size=352x288:rate=25:duration=1" \
    -f lavfi -i "sine=sample_rate=44100:duration=1" -c:v mpeg1video -c:a mp2 -ac 2 -f vcd "${BATS_FILE_TMPDIR}/vcd.mpg"
}

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/yk-svcd.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
  CLIPS="$(cd "${BATS_FILE_TMPDIR}" && pwd -P)"
  OUT="${WORK}/out"
}

teardown() {
  rm -rf "${WORK}"
}

stream_line_is() {
  local found
  found="$("${YAKITSUKE_TEST_FFMPEG%/ffmpeg}/ffprobe" -v error -show_entries stream=codec_name,width,height,display_aspect_ratio \
    -of csv=p=0 "$1")"
  [[ "${found//$'\n'/ }" == "$2" ]]
}

image_is_svcd() {
  local report
  report="$(vcd-info --bin-file "$1" 2>/dev/null)" || return 1
  [[ "${report}" == *"SVCD detected"* ]]
}

@test "a run without --format still writes a Video CD" {
  # Arrange
  local clip="${CLIPS}/square.mp4"

  # Act
  run yk_test_run --dry-run --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Target: PAL Video CD, 352x288 at 25 fps"* ]]
}

@test "--format svcd targets a PAL Super Video CD at 480x576" {
  # Arrange
  local clip="${CLIPS}/square.mp4"

  # Act
  run yk_test_run --format svcd --dry-run --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Target: PAL Super Video CD, 480x576 at 25 fps"$'\n'"        4:3, video 2040 to 2450 kbit/s average, filling each disc"* ]]
}

@test "YAKITSUKE_FORMAT picks the format and --format wins over it" {
  # Arrange
  local clip="${CLIPS}/square.mp4"

  # Act
  YAKITSUKE_FORMAT=svcd run yk_test_run --dry-run --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${output}" == *"PAL Super Video CD"* ]]
  YAKITSUKE_FORMAT=svcd run yk_test_run --format vcd --dry-run --output-dir "${OUT}" "${clip}"
  [[ "${output}" == *"PAL Video CD, 352x288"* ]]
}

@test "an unknown format is refused from the option and from the environment" {
  # Arrange
  local clip="${CLIPS}/square.mp4"

  # Act
  run yk_test_run --format dvd --dry-run "${clip}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: --format must be vcd or svcd, got: dvd" ]]
  YAKITSUKE_FORMAT=dvd run yk_test_run --dry-run "${clip}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: YAKITSUKE_FORMAT must be vcd or svcd, got: dvd" ]]
}

@test "--aspect 16:9 needs a Super Video CD and a bad aspect is refused" {
  # Arrange
  local clip="${CLIPS}/wide.mp4"

  # Act
  run yk_test_run --aspect 16:9 --dry-run "${clip}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: --aspect 16:9 needs --format svcd" ]]
  run yk_test_run --format svcd --aspect 21:9 --dry-run "${clip}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: --aspect must be auto, 4:3 or 16:9, got: 21:9" ]]
}

@test "a wide source becomes 16:9 on SVCD unless --aspect 4:3 asks otherwise" {
  # Arrange
  local clip="${CLIPS}/wide.mp4"

  # Act
  run yk_test_run --format svcd --dry-run --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${output}" == *"        16:9, video 2040 to 2450 kbit/s average"* ]]
  run yk_test_run --format svcd --aspect 4:3 --dry-run --output-dir "${OUT}" "${clip}"
  [[ "${output}" == *"        4:3, video 2040 to 2450 kbit/s average"* ]]
}

@test "--aspect 16:9 makes a 4:3 source a 16:9 Super Video CD" {
  # Arrange
  local clip="${CLIPS}/square.mp4"

  # Act
  run yk_test_run --format svcd --aspect 16:9 --dry-run --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"        16:9, video 2040 to 2450 kbit/s average"* ]]
}

@test "an 80-minute disc holds about 48 minutes of SVCD at the reference rate" {
  # Arrange
  local minutes=80

  # Act
  YK_FORMAT=svcd run yk_test_call call_usable "${minutes}"

  # Assert
  [[ "${output}" == "2888.697" ]]
}

@test "the SVCD picture chain scales to the 704-active line and pads to 480" {
  # Arrange
  local expected="scale=470:576:flags=lanczos+accurate_rnd+full_chroma_int,unsharp=5:5:0.4:5:5:0.0,pad=480:576:4:0:color=black"

  # Act
  YK_FORMAT=svcd YK_ZSCALE=no YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph

  # Assert
  [[ "${output}" == *"${expected}"* ]]
}

@test "SVCD subtitles are scaled to the picture line and padded with transparency" {
  # Arrange
  local expected="scale=470:576:flags=lanczos,pad=480:576:5:0:color=black@0,format=yuva444p"

  # Act
  YK_FORMAT=svcd YK_SUB_MASTER=/m.ass YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph 12.5

  # Assert
  [[ "${output}" == *"${expected}"* ]]
}

@test "a Video CD stream fails the Super Video CD conformance check" {
  # Arrange
  local stream="${CLIPS}/vcd.mpg"

  # Act
  YK_FORMAT=svcd run yk_test_call call_verify "${stream}" pal

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${lines[0]}" == "yakitsuke: the stream is not Super Video CD conformant: vcd.mpg" ]]
  [[ "${lines[1]}" == "yakitsuke:   expected: mpeg2video 480 576 mp2 44100 2" ]]
}

@test "ffmpeg writes a PAL 16:9 Super Video CD image" {
  # Arrange
  local clip="${CLIPS}/wide.mp4"

  # Act
  run yk_test_run --format svcd --encoder ffmpeg --keep-mpeg --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  stream_line_is "${OUT}/wide_disc1.mpg" "mpeg2video,480,576,16:9, mp2"
  image_is_svcd "${OUT}/wide_disc1.bin"
}

@test "mpeg2enc writes an NTSC Super Video CD image at 480x480" {
  # Arrange
  local clip="${CLIPS}/ntsc.mp4"

  # Act
  run yk_test_run --format svcd --encoder mpeg2enc --keep-mpeg --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  stream_line_is "${OUT}/ntsc_disc1.mpg" "mpeg2video,480,480,16:9, mp2"
  image_is_svcd "${OUT}/ntsc_disc1.bin"
}

# bats test_tags=libass
@test "subtitles burn into a Super Video CD" {
  # Arrange
  local clip="${CLIPS}/square.mp4"

  # Act
  run yk_test_run --format svcd --encoder ffmpeg --output-dir "${OUT}" "${clip}" "${CLIPS}/one.srt"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"subtitles burned in: 1 lines"* ]]
  [[ -s "${OUT}/square_disc1.bin" ]]
}

@test "each SVCD disc's average rate fills it, between the reference and the ceiling" {
  # Arrange
  local rates=""
  local span

  # Act
  for span in 2400 2600 2888.697 3000; do
    rates="${rates}$(YK_FORMAT=svcd yk_test_call call_rate 80 "${span}") "
  done

  # Assert
  [[ "${rates}" == "2450 2291 2040 2040 " ]]
}

@test "an SVCD disc that overflows is encoded again at 3% less, then fits" {
  # Arrange
  local clip="${CLIPS}/square.mp4"
  yk_test_shim vcdxbuild '"$REAL" "$@" || exit 1; [ -e "'"${WORK}"'/padded" ] && exit 0; : >"'"${WORK}"'/padded"; dd if=/dev/zero bs=2352 count=5000 2>/dev/null >>"$4"'

  # Act
  run yk_test_run --format svcd --encoder ffmpeg --disc-minutes 1 --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"yakitsuke: warning: disc 1 of 1 does not fit; encoding it again at 2376 kbit/s."* ]]
  [[ "${output}" == *"Disc 1 of 1, encoding 3.000s from 0.000s at 2376 kbit/s"* ]]
  [[ -s "${OUT}/square_disc1.bin" ]]
}

@test "an SVCD disc that never fits stops after three tries and leaves no staging folder" {
  # Arrange
  local clip="${CLIPS}/square.mp4"
  local leftovers
  yk_test_shim vcdxbuild '"$REAL" "$@" || exit 1; dd if=/dev/zero bs=2352 count=5000 2>/dev/null >>"$4"'

  # Act
  run yk_test_run --format svcd --encoder ffmpeg --disc-minutes 1 --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"encoding it again at 2234 kbit/s."* ]]
  [[ "${output}" == *"yakitsuke: 1 image(s) do not fit the selected media."* ]]
  leftovers="$(find "${OUT}" -name '.yakitsuke.*')"
  [[ -z "${leftovers}" ]]
}

repeated_frames() {
  local flags
  flags="$("${YAKITSUKE_TEST_FFMPEG%/ffmpeg}/ffprobe" -v error -show_entries frame=repeat_pict -of csv=p=0 "$1")"
  printf '%s\n' "${flags}" | awk -F, '$1 == 1 { n++ } END { print n + 0 }'
}

frame_rate_is() {
  local rate
  rate="$("${YAKITSUKE_TEST_FFMPEG%/ffmpeg}/ffprobe" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$1")"
  [[ "${rate%,}" == "$2" ]]
}

@test "mpeg2enc keeps NTSC film at 23.976 with 3:2 pulldown flags on SVCD" {
  # Arrange
  local clip="${CLIPS}/film.mp4"
  local repeated

  # Act
  run yk_test_run --format svcd --encoder mpeg2enc --keep-mpeg --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"        film kept at 23.976 fps, shown at 29.97 through 3:2 pulldown flags"* ]]
  repeated="$(repeated_frames "${OUT}/film_disc1.mpg")"
  [[ "${repeated}" -gt 30 ]]
  image_is_svcd "${OUT}/film_disc1.bin"
}

@test "ffmpeg brings NTSC film to 29.97 frames on SVCD, without pulldown flags" {
  # Arrange
  local clip="${CLIPS}/film.mp4"

  # Act
  run yk_test_run --format svcd --encoder ffmpeg --keep-mpeg --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" != *"pulldown"* ]]
  frame_rate_is "${OUT}/film_disc1.mpg" 30000/1001
}

field_order_is() {
  local order
  order="$("${YAKITSUKE_TEST_FFMPEG%/ffmpeg}/ffprobe" -v error -select_streams v:0 -show_entries stream=field_order -of csv=p=0 "$1")"
  [[ "${order%,}" == "$2" ]]
}

@test "ffmpeg keeps the fields of a top-field-first 576i source on PAL SVCD" {
  # Arrange
  local clip="${CLIPS}/tff576.mp4"

  # Act
  run yk_test_run --format svcd --encoder ffmpeg --keep-mpeg --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"        fields kept interlaced, tff first, no denoise or sharpening"* ]]
  field_order_is "${OUT}/tff576_disc1.mpg" tt
}

@test "mpeg2enc keeps the fields of a bottom-field-first 576i source on PAL SVCD" {
  # Arrange
  local clip="${CLIPS}/bff576.mp4"

  # Act
  run yk_test_run --format svcd --encoder mpeg2enc --keep-mpeg --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"        fields kept interlaced, bff first"* ]]
  field_order_is "${OUT}/bff576_disc1.mpg" bb
}

@test "an interlaced source that needs vertical scaling is deinterlaced on SVCD" {
  # Arrange
  local clip="${CLIPS}/tff480.mp4"

  # Act
  run yk_test_run --format svcd --pal --dry-run --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"        deinterlace on, denoise off"* ]]
}

@test "an interlaced source on Video CD is still deinterlaced" {
  # Arrange
  local clip="${CLIPS}/tff576.mp4"

  # Act
  run yk_test_run --dry-run --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"        deinterlace on, denoise off"* ]]
}

@test "kept fields scale line by line and skip sharpening and denoise" {
  # Arrange
  local expected="[0:v:0]fps=25,scale=470:576:interl=1:flags=lanczos+accurate_rnd+full_chroma_int,pad=480:576:4:0:color=black,format=yuv420p,setfield=bff,setsar=1[v]"

  # Act
  YK_FORMAT=svcd YK_FIELD_MODE=keep YK_FIELD_ORDER=bff YK_DENOISE=1.5 YK_SRC_W=720 YK_SRC_H=576 YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph

  # Assert
  [[ "${output}" == "${expected}" ]]
}
