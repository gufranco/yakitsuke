#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  yk_test_media "${BATS_FILE_TMPDIR:?}/pal.mp4" 4 320x240 25
  yk_test_media "${BATS_FILE_TMPDIR:?}/long.mp4" 50 160x120 25
  yk_test_srt "${BATS_FILE_TMPDIR:?}/two.srt" 2
}

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/yk-golden.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
  CLIPS="$(cd "${BATS_FILE_TMPDIR}" && pwd -P)"
  OUT="${WORK}/out"
}

teardown() {
  rm -rf "${WORK}"
}

# bats test_tags=libass
@test "a dry run prints the same transcript as the recorded one" {
  # Arrange
  local clip="${CLIPS}/pal.mp4"

  # Act
  run yk_test_run --dry-run --output-dir "${OUT}" "${clip}" "${CLIPS}/two.srt"

  # Assert
  [[ "${status}" -eq 0 ]]
  yk_test_matches_golden dry-run "${output}"
}

@test "a dry run across discs prints the same transcript as the recorded one" {
  # Arrange
  local clip="${CLIPS}/long.mp4"

  # Act
  run yk_test_run --dry-run --disc-minutes 1 --overlap 5 --chapters 0 --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  yk_test_matches_golden dry-run-discs "${output}"
}
