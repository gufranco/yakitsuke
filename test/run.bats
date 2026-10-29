#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  local dir="${BATS_FILE_TMPDIR:?}"
  yk_test_media "${dir}/pal.mp4" 4 320x240 25
  yk_test_media "${dir}/film.mp4" 4 640x272 24000/1001 -vf "pad=640:360:0:44:black"
  yk_test_media "${dir}/long.mp4" 50 160x120 25
  "${YAKITSUKE_TEST_FFMPEG}" -hide_banner -v error -y -f lavfi -i "color=c=red:s=160x120:r=25:d=30" \
    -f lavfi -i "color=c=blue:s=160x120:r=25:d=30" -filter_complex "[0][1]concat=n=2:v=1:a=0" \
    -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p "${dir}/cut.mp4"
  "${YAKITSUKE_TEST_FFMPEG}" -hide_banner -v error -y -f lavfi -i "testsrc2=size=320x240:rate=25:duration=3" \
    -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p "${dir}/silent.mp4"
  yk_test_srt "${dir}/two.srt" 2
}

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/yk-run.XXXXXX")"
  OUT="${WORK}/out"
}

teardown() {
  rm -rf "${WORK}"
}

yk_header() {
  python3 - "$1" <<'PY'
import sys
d = open(sys.argv[1], "rb").read()
i = d.find(b"\x00\x00\x01\xb3")
bits = int.from_bytes(d[i + 4:i + 12], "big")
print("%dx%d rate=%d vbv=%d" % (bits >> 52, (bits >> 40) & 0xFFF, (bits >> 32) & 0xF, (bits >> 3) & 0x3FF))
PY
}

@test "the cue sheet names its image without a folder, so the pair can move together" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/pal.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  grep -qF 'FILE "pal_disc1.bin" BINARY' "${OUT}/pal_disc1.cue"
}

@test "an image build that fails half way leaves no image and no staging folder behind" {
  # Arrange
  mkdir -p "${OUT}"
  yk_test_shim vcdxbuild "while [ \"\$#\" -gt 0 ]; do
  case \"\$1\" in
  -b) printf partial >\"\$2\"; shift 2 ;;
  *) shift ;;
  esac
done
exit 1"

  # Act
  run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -ne 0 ]]
  shopt -s nullglob dotglob
  local left=("${OUT}"/*)
  [[ "${#left[@]}" -eq 0 ]]
}

@test "a PAL source becomes a verified PAL Video CD image" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/pal.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --keep-mpeg "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Target: PAL Video CD, 352x288 at 25 fps"* ]]
  local real
  real="$(cd "${OUT}" && pwd -P)"
  [[ "${output}" == *"Wrote 1 Video CD image(s) to ${real}."* ]]
  [[ -s "${OUT}/pal_disc1.bin" && -s "${OUT}/pal_disc1.cue" ]]
  local header
  header="$(yk_header "${OUT}/pal_disc1.mpg")"
  [[ "${header}" == "352x288 rate=3 vbv=20" ]]
}

@test "film keeps its 23.976 frame rate and subtitles land in the bar" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/film.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --keep-mpeg "${clip}" "${BATS_FILE_TMPDIR}/two.srt"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"black bars stripped, active picture 640x272 at +0+44"* ]]
  [[ "${output}" == *"subtitles burned in: 2 lines"* ]]
  local header
  header="$(yk_header "${OUT}/film_disc1.mpg")"
  [[ "${header}" == "352x240 rate=1 vbv=20" ]]
  local luma
  luma="$(yk_test_frame_luma "${OUT}/film_disc1.mpg" 0.5 352:40:0:196)"
  [[ "${luma}" -gt 180 ]]
}

@test "film forced to PAL is sped up and keeps its pitch" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/film.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --pal --keep-mpeg "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"film sped up to 25 fps, 1.042708x, pitch kept"* ]]
  local header
  header="$(yk_header "${OUT}/film_disc1.mpg")"
  [[ "${header}" == "352x288 rate=3 vbv=20" ]]
}

@test "a forced NTSC target is honoured" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/pal.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --ntsc --crop --keep-mpeg "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  local header
  header="$(yk_header "${OUT}/pal_disc1.mpg")"
  [[ "${header}" == "352x240 rate=4 vbv=20" ]]
}

@test "the ffmpeg encoder builds a valid image too" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/pal.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --encoder ffmpeg "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Plan:   1 disc(s), 30s overlap, ffmpeg"* ]]
  [[ -s "${OUT}/pal_disc1.bin" ]]
}

@test "a source without audio gets a silent track" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/silent.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --normalize --keep-mpeg "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"audio silent, the source has none"* ]]
  [[ "${output}" == *"loudness measurement failed, falling back to single-pass normalisation"* ]]
  [[ -s "${OUT}/silent_disc1.mpg" ]]
}

@test "loudness is measured before encoding when asked" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/pal.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --normalize "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Loudness measured; applying an exact correction."* ]]
}

@test "a long source is split across discs with a seam overlap" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/long.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --disc-minutes 1 --overlap 5 --chapters 0 "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Plan:   2 disc(s), 5s overlap"* ]]
  [[ -s "${OUT}/long_disc1.bin" && -s "${OUT}/long_disc2.bin" ]]
}

@test "a dry run prints the plan and writes nothing" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/long.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --disc-minutes 1 --overlap 5 --dry-run "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Disc 2 of 2 would hold "* ]]
  [[ ! -e "${OUT}/long_disc1.bin" ]]
}

@test "a preview encodes one short sample" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/long.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --preview 2 "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Plan:   preview only, one 2s sample from the middle"* ]]
  [[ -s "${OUT}/long_preview_disc1.bin" ]]
}

@test "an existing image is never overwritten without --force" {
  # Arrange
  mkdir -p "${OUT}"
  printf 'keep\n' >"${OUT}/pal_disc1.bin"

  # Act
  run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"refusing to overwrite pal_disc1.bin; pass --force or --resume"* ]]
  local kept
  kept="$(cat "${OUT}/pal_disc1.bin")"
  [[ "${kept}" == "keep" ]]
}

@test "--force replaces an existing image" {
  # Arrange
  mkdir -p "${OUT}"
  printf 'old\n' >"${OUT}/pal_disc1.bin"

  # Act
  run yk_test_run --output-dir "${OUT}" --force "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 0 ]]
  local bytes
  bytes="$(wc -c <"${OUT}/pal_disc1.bin")"
  [[ "${bytes}" -gt 100000 ]]
}

@test "--resume keeps a disc that is already there" {
  # Arrange
  run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --resume "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Disc 1 of 1: already present, keeping it."* ]]
}

@test "--resume encodes again a disc whose image cannot be used" {
  # Arrange
  mkdir -p "${OUT}"
  head -c 11000000 /dev/zero >"${OUT}/pal_disc1.bin"
  printf 'cue\n' >"${OUT}/pal_disc1.cue"

  # Act
  run yk_test_run --output-dir "${OUT}" --resume --disc-minutes 1 "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"disc 1 of 1: the existing image is unusable, encoding it again"* ]]
}

@test "a failing ffmpeg stops the run and shows its error" {
  # Arrange
  yk_test_shim ffmpeg "case \"\$*\" in *yuv4mpegpipe*) printf \"boom from ffmpeg\\n\" >&2; exit 1 ;; esac
exec \"\$REAL\" \"\$@\""

  # Act
  YAKITSUKE_FFMPEG="${SHIMS}/ffmpeg" run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"yakitsuke: encoding failed."* ]]
  [[ "${output}" == *"boom from ffmpeg"* ]]
}

@test "a failing mpeg2enc stops the run" {
  # Arrange
  yk_test_shim mpeg2enc "cat >/dev/null; exit 1"

  # Act
  run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"yakitsuke: encoding failed."* ]]
}

@test "a failing ffmpeg encoder stops the run" {
  # Arrange
  yk_test_shim ffmpeg "case \"\$*\" in *muxrate*) exit 1 ;; esac
exec \"\$REAL\" \"\$@\""

  # Act
  YAKITSUKE_FFMPEG="${SHIMS}/ffmpeg" run yk_test_run --output-dir "${OUT}" --encoder ffmpeg "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"yakitsuke: encoding failed."* ]]
}

@test "mplex failing without output stops the run" {
  # Arrange
  yk_test_shim mplex "printf \"mplex broke\\n\" >&2; exit 1"

  # Act
  run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"yakitsuke: mplex failed"* ]]
  [[ "${output}" == *"mplex broke"* ]]
}

@test "an mplex warning with output still checks the stream" {
  # Arrange
  yk_test_shim mplex "\"\$REAL\" \"\$@\"; exit 1"

  # Act
  run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"mplex reported a buffer margin warning; the stream is checked next"* ]]
}

@test "a stream that is not Video CD conformant is refused" {
  # Arrange
  yk_test_shim ffprobe "case \"\$*\" in *v:0*stream=width*disc1.mpg*) printf \"353\\n\"; exit 0 ;; esac
exec \"\$REAL\" \"\$@\""
  mkdir -p "${WORK}/lone"
  ln -s "${YAKITSUKE_TEST_FFMPEG}" "${WORK}/lone/ffmpeg"

  # Act
  YAKITSUKE_FFMPEG="${WORK}/lone/ffmpeg" run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"the stream is not Video CD conformant: disc1.mpg"* ]]
  [[ "${output}" == *"  found:    mpeg1video 353 288 mp2 44100 2"* ]]
}

@test "an encoder that writes nothing is reported" {
  # Arrange
  yk_test_shim mplex ": >\"\$4\"; exit 0"

  # Act
  run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"the encoder produced no data: disc1.mpg"* ]]
}

@test "a vcdxbuild failure stops the run with its message" {
  # Arrange
  yk_test_shim vcdxbuild "printf \"vcdxbuild broke\\n\" >&2; exit 1"

  # Act
  run yk_test_run --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"vcdxbuild failed on disc 1"* ]]
  [[ "${output}" == *"vcdxbuild broke"* ]]
}

@test "an image larger than the media is reported" {
  # Arrange
  yk_test_shim vcdxbuild "\"\$REAL\" \"\$@\" || exit 1
head -c 11000000 /dev/zero >>\"\$4\""

  # Act
  run yk_test_run --output-dir "${OUT}" --disc-minutes 1 "${BATS_FILE_TMPDIR}/pal.mp4"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"the image needs "*" sectors and the media holds 4500"* ]]
  [[ "${output}" == *"1 image(s) do not fit the selected media"* ]]
}

@test "a seam near a scene change is moved onto it" {
  # Arrange
  local clip="${BATS_FILE_TMPDIR}/cut.mp4"

  # Act
  run yk_test_run --output-dir "${OUT}" --disc-minutes 1 --overlap 5 --scene-snap 15 --dry-run "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"seams snapped to the nearest scene change within 15s"* ]]
  [[ "${output}" == *"Disc 1 of 2 would hold 30.000s from 0.000s: "* ]]
}

@test "an interrupted run removes its working folder" {
  # Arrange
  mkdir -p "${WORK}/tmp"
  yk_test_shim mpeg2enc "cat >/dev/null; sleep 2; exit 1"
  local -a shell_words
  read -r -a shell_words <<<"${YAKITSUKE_TEST_SHELL:-sh}"
  local search
  search="$(yk_test_path)"

  # Act
  TMPDIR="${WORK}/tmp" PATH="${search}" YAKITSUKE_FFMPEG="${YAKITSUKE_TEST_FFMPEG}" \
    "${shell_words[@]}" "${REPO_DIR}/bin/yakitsuke" --output-dir "${OUT}" "${BATS_FILE_TMPDIR}/pal.mp4" >/dev/null 2>&1 &
  local pid="$!"
  local tries=0
  until compgen -G "${WORK}/tmp/yakitsuke.*/fonts" >/dev/null || [[ "${tries}" -ge 150 ]]; do
    sleep 0.2
    tries=$((tries + 1))
  done
  local target
  for target in $(pgrep -f "bin/yakitsuke --output-dir ${OUT}"); do
    case "$(ps -o comm= -p "${target}")" in
    *sh) kill -TERM "${target}" 2>/dev/null || true ;;
    *) ;;
    esac
  done
  wait "${pid}" && status=0 || status=$?

  # Assert
  [[ "${status}" -eq 130 ]]
  run compgen -G "${WORK}/tmp/yakitsuke.*"
  [[ "${status}" -ne 0 ]]
}
