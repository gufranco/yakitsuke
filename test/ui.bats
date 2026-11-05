#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  yk_test_media "${BATS_FILE_TMPDIR:?}/clip.mp4" 2 160x120 25
}

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/yk-ui.XXXXXX")"
  OUT="${WORK}/out"
  CLIP="${BATS_FILE_TMPDIR}/clip.mp4"
  unset KODOUGU_THEME KODOUGU_ACCENT YAKITSUKE_THEME NO_COLOR
  export YAKITSUKE_TEST_GUM=1
  export YAKITSUKE_TEST_GUM_LOG="${WORK}/gum.log"
  export YAKITSUKE_TEST_GUM_ANSWERS="${WORK}/answers"
  export YAKITSUKE_INTERACTIVE=1
  : >"${YAKITSUKE_TEST_GUM_LOG}"
}

teardown() {
  rm -rf "${WORK}"
}

answers() {
  printf '%s\n' "$@" >"${YAKITSUKE_TEST_GUM_ANSWERS}"
}

no_image() {
  local found
  found="$(find "${WORK}" -name '*.bin')"
  [[ -z "${found}" ]]
}

never_called() {
  if grep -q -F -- "$1" "${YAKITSUKE_TEST_GUM_LOG}"; then
    return 1
  fi
}

called() {
  grep -q -F -- "$1" "${YAKITSUKE_TEST_GUM_LOG}"
}

@test "the video is asked for under the header and encoded after a yes" {
  # Arrange
  answers "${CLIP}" "" "yes"

  # Act
  run yk_test_run --output-dir "${OUT}" </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"burn any video onto Video CD or Super Video CD images"* ]]
  [[ "${output}" == *"Source:"*"clip.mp4"* ]]
  [[ "${output}" == *"Wrote 1 Video CD image(s) to "*"/out."* ]]
  [[ -s "${OUT}/clip_disc1.bin" ]]
  called "input --header Video file"
  called "input --header Subtitle file"
  called "confirm Encode 1 disc(s)?"
}

@test "the encode draws a progress bar" {
  # Arrange
  local bar
  bar="$(printf '\342\224\201')"
  answers "yes"

  # Act
  run yk_test_run --output-dir "${OUT}" "${CLIP}" </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"${bar}"*"100%"* ]]
}

@test "a no at the confirmation encodes nothing" {
  # Arrange
  answers "no"

  # Act
  run yk_test_run --output-dir "${OUT}" "${CLIP}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR yakitsuke: stopped: nothing was encoded."* ]]
  no_image
}

@test "a dry run asks nothing" {
  # Arrange
  answers "<cancel>"

  # Act
  run yk_test_run --output-dir "${OUT}" --dry-run "${CLIP}" </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  no_image
  never_called "confirm"
}

@test "a cancelled video prompt stops the run" {
  # Arrange
  answers "<cancel>"

  # Act
  run yk_test_run --output-dir "${OUT}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  no_image
}

@test "doctor draws its rows in a table" {
  # Arrange
  local expected="vcdxbuild"

  # Act
  run yk_test_run doctor </dev/null

  # Assert
  [[ "${output}" == *"Tool"*"State"*"Detail"* ]]
  [[ "${output}" == *"${expected}"* ]]
}

@test "doctor reports a missing tool below the table" {
  # Arrange
  local farm
  farm="$(yk_test_farm vcdxbuild)"

  # Act
  run yk_test_run_path "${farm}" doctor </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR yakitsuke: a required tool is missing."* ]]
}

@test "doctor fails without gum" {
  # Arrange
  local farm
  farm="$(yk_test_farm gum)"

  # Act
  YAKITSUKE_TEST_GUM=0 run yk_test_run_path "${farm}" doctor </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"gum                missing  install with: brew install gum"* ]]
}

@test "version shows the version and platform as badges" {
  # Arrange
  local version
  version="$(sed -n 's/^YAKITSUKE_VERSION="\(.*\)"$/\1/p' "${REPO_DIR}/lib/core.sh")"

  # Act
  run yk_test_run version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "yakitsuke ${version} platform "* ]]
}

@test "help is formatted with gum" {
  # Arrange
  local expected="## Usage"

  # Act
  run yk_test_run help </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"${expected}"* ]]
  called "format --theme pink"
}

@test "--theme picks the palette over the environment" {
  # Arrange
  local theme="nord"

  # Act
  KODOUGU_THEME=dracula YAKITSUKE_THEME=gruvbox run yk_test_run --theme "${theme}" version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  called "--background #88C0D0"
}

@test "--theme= with a value picks the palette" {
  # Arrange
  local option="--theme=tokyo-night"

  # Act
  run yk_test_run "${option}" version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  called "--background #7AA2F7"
}

@test "an unknown theme stops before anything runs" {
  # Arrange
  local theme="solarized"

  # Act
  KODOUGU_THEME="${theme}" run yk_test_run --output-dir "${OUT}" "${CLIP}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"got: solarized"* ]]
  no_image
}

@test "--theme without a value stops with the usage hint" {
  # Arrange
  local option="--theme"

  # Act
  run yk_test_run version "${option}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"option '--theme' needs a value. run 'yakitsuke help' for usage."* ]]
}

@test "--theme after -- names a video" {
  # Arrange
  local option="--theme"

  # Act
  run yk_test_run --dry-run -- "${option}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"--theme"* ]]
}

@test "a warning is drawn with the WARN level" {
  # Arrange
  yk_test_shim mplex "\"\$REAL\" \"\$@\"; exit 1"
  answers "yes"

  # Act
  run yk_test_run --output-dir "${OUT}" "${CLIP}" </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"left   "$'\n'"WARN yakitsuke: mplex reported a buffer margin warning;"* ]]
}

@test "a failed encode closes the bar line before the error" {
  # Arrange
  yk_test_shim ffmpeg "case \"\$*\" in *progress*)
  \"\$REAL\" \"\$@\"
  i=0
  while [ ! -e bar.open ] && [ \"\$i\" -lt 100 ]; do sleep 0.1; i=\$((i + 1)); done
  exit 1 ;;
esac
exec \"\$REAL\" \"\$@\""
  answers "yes"

  # Act
  YAKITSUKE_FFMPEG="${SHIMS}/ffmpeg" run yk_test_run --output-dir "${OUT}" "${CLIP}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"left   "$'\n'"ERROR yakitsuke: encoding failed."* ]]
}
