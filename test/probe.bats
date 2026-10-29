#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  local dir="${BATS_FILE_TMPDIR:?}"
  yk_test_media "${dir}/progressive.mp4" 8 640x480 25
  yk_test_media "${dir}/interlaced.mp4" 8 640x480 50 -vf "interlace=scan=tff,setfield=tff" -flags +ildct+ilme
  yk_test_media "${dir}/telecined.mp4" 8 640x480 24000/1001 -vf "telecine=first_field=t:pattern=23"
  yk_test_media "${dir}/short.mp4" 1 640x480 25
  yk_test_media "${dir}/letterboxed.mp4" 6 1280x536 25 -vf "pad=1280:720:0:92:black"
  yk_test_media "${dir}/mono.mp4" 6 640x480 25 -vf "hue=s=0"
  "${YAKITSUKE_TEST_FFMPEG}" -hide_banner -v error -y -f lavfi -i "color=c=red:s=320x240:r=25:d=4" \
    -f lavfi -i "color=c=blue:s=320x240:r=25:d=4" -filter_complex "[0][1]concat=n=2:v=1:a=0" \
    -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p "${dir}/cut.mp4"
  "${YAKITSUKE_TEST_FFMPEG}" -hide_banner -v error -y -f lavfi -i "sine=frequency=440:sample_rate=48000:duration=3" \
    -c:a aac "${dir}/audio.m4a"
  printf 'not a video\n' >"${dir}/text.mp4"
}

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/yk-probe.XXXXXX")"
}

teardown() {
  rm -rf "${WORK}"
}

@test "a progressive source needs no deinterlacing" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/progressive.mp4"

  # Act
  run yk_test_call call_detect yk_detect_field_mode "${clip}"

  # Assert
  [[ "${output}" == "off" ]]
}

@test "an interlaced video source is deinterlaced" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/interlaced.mp4"

  # Act
  run yk_test_call call_detect yk_detect_field_mode "${clip}"

  # Assert
  [[ "${output}" == "on" ]]
}

@test "telecined film is recovered with inverse telecine" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/telecined.mp4"

  # Act
  run yk_test_call call_detect yk_detect_field_mode "${clip}"

  # Assert
  [[ "${output}" == "ivtc" ]]
}

@test "a source too short to judge is treated as progressive" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/short.mp4"

  # Act
  run yk_test_call call_detect yk_detect_field_mode "${clip}"

  # Assert
  [[ "${output}" == "off" ]]
}

@test "baked-in black bars are found" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/letterboxed.mp4"

  # Act
  run yk_test_call call_detect yk_detect_borders "${clip}"

  # Assert
  [[ "${output}" == "1280 536 0 92" ]]
}

@test "a source without bars keeps its full frame" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/progressive.mp4"

  # Act
  run yk_test_call call_detect yk_detect_borders "${clip}"

  # Assert
  [[ "${output}" == "640 480 0 0" ]]
}

@test "a box larger than the frame is ignored" {
  # Arrange
  yk_test_shim ffmpeg "case \"\$*\" in *cropdetect*) printf \"crop=9999:9999:0:0\\n\" >&2; exit 0 ;; esac
exec \"\$REAL\" \"\$@\""
  local clip="${BATS_FILE_TMPDIR}/progressive.mp4"

  # Act
  YAKITSUKE_FFMPEG="${SHIMS}/ffmpeg" run yk_test_call call_detect yk_detect_borders "${clip}"

  # Assert
  [[ "${output}" == "640 480 0 0" ]]
}

@test "a black and white source is recognised" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/mono.mp4"

  # Act
  run yk_test_call call_detect yk_detect_monochrome "${clip}"

  # Assert
  [[ "${output}" == "yes" ]]
}

@test "a colour source is not taken for black and white" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/progressive.mp4"

  # Act
  run yk_test_call call_detect yk_detect_monochrome "${clip}"

  # Assert
  [[ "${output}" == "no" ]]
}

@test "loudness is measured into an exact two-pass correction" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/progressive.mp4"

  # Act
  run yk_test_call yk_loudnorm_measure "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ ^loudnorm=I=-20:TP=-2:LRA=11:measured_I=-?[0-9.]+:measured_TP=-?[0-9.]+:measured_LRA=[0-9.]+:measured_thresh=-?[0-9.]+:linear=true$ ]]
}

@test "loudness measurement fails cleanly without audio" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/cut.mp4"

  # Act
  run yk_test_call yk_loudnorm_measure "${clip}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ -z "${output}" ]]
}

@test "a seam is moved onto the nearest scene change" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/cut.mp4"

  # Act
  run yk_test_call yk_scene_snap "${clip}" 3.5 2

  # Assert
  [[ "${output}" == "4.000" ]]
}

@test "no scene change in the window leaves the seam alone" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/cut.mp4"

  # Act
  run yk_test_call yk_scene_snap "${clip}" 1 1

  # Assert
  [[ -z "${output}" ]]
}

@test "probing reads the duration, size, rate and audio" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/progressive.mp4"

  # Act
  run yk_test_call call_probe "${clip}"

  # Assert
  [[ "${output}" =~ ^duration=8\.[0-9]+\ size=640x480\ fps=25/1\ audio=yes$ ]]
}

@test "a source without audio is noted" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/cut.mp4"

  # Act
  run yk_test_call call_probe "${clip}"

  # Assert
  [[ "${output}" == *"audio=no" ]]
}

@test "a file with no video stream is refused" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/audio.m4a"

  # Act
  run yk_test_call call_probe "${clip}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: the source has no readable video stream: audio.m4a" ]]
}

@test "a file that is not media has no duration" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/text.mp4"

  # Act
  run yk_test_call call_probe "${clip}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: could not read a usable duration from text.mp4" ]]
}

@test "the duration falls back to the video stream when the container has none" {
  # Arrange
  yk_test_shim ffprobe "case \"\$*\" in *format=duration*) printf \"N/A\\n\"; exit 0 ;; esac
exec \"\$REAL\" \"\$@\""
  mkdir -p "${WORK}/lone"
  ln -s "${YAKITSUKE_TEST_FFMPEG}" "${WORK}/lone/ffmpeg"
  local clip="${BATS_FILE_TMPDIR}/progressive.mp4"

  # Act
  YAKITSUKE_FFMPEG="${WORK}/lone/ffmpeg" run yk_test_call yk_probe_duration "${clip}"

  # Assert
  [[ "${output}" =~ ^8\.[0-9]+$ ]]
}

@test "an unusable YAKITSUKE_FFMPEG is passed over for a working build" {
  # Arrange
  local bogus="${BATS_TMPDIR}/not-ffmpeg-$$"

  # Act
  YAKITSUKE_FFMPEG="${bogus}" run yk_test_call yk_resolve_ffmpeg no

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" != "${bogus}" ]]
  [[ -x "${output}" ]]
}

@test "ffprobe is found on PATH when it is not next to ffmpeg" {
  # Arrange
  mkdir -p "${WORK}/lone"
  ln -s "${YAKITSUKE_TEST_FFMPEG}" "${WORK}/lone/ffmpeg"
  local expected
  expected="$(command -v ffprobe)"

  # Act
  YAKITSUKE_FFMPEG="${WORK}/lone/ffmpeg" run yk_test_call yk_resolve_ffprobe

  # Assert
  [[ "${output}" == "${expected}" ]]
}
