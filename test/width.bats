#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  yk_test_media "${BATS_FILE_TMPDIR:?}/clip.mp4" 2 320x240 25
}

setup() {
  WORK="$(mktemp -d /tmp/yk-width.XXXXXX)"
  WORK="$(cd "${WORK}" && pwd -P)"
  CLIP="${BATS_FILE_TMPDIR}/clip.mp4"
}

teardown() {
  rm -rf "${WORK}"
}

widest_line() {
  awk '{ if (length($0) > widest) { widest = length($0) } } END { print widest + 0 }'
}

@test "help never prints a line wider than 80 columns" {
  # Arrange
  local page widest

  # Act
  page="$(YAKITSUKE_TERMINAL=1 yk_test_run help)"

  # Assert
  widest="$(printf '%s\n' "${page}" | widest_line)"
  [[ "${widest}" -le 80 ]]
}

@test "version never prints a line wider than 80 columns" {
  # Arrange
  local page widest

  # Act
  page="$(YAKITSUKE_TERMINAL=1 yk_test_run version)"

  # Assert
  widest="$(printf '%s\n' "${page}" | widest_line)"
  [[ "${widest}" -le 80 ]]
}

@test "an error longer than 80 columns wraps between words" {
  # Arrange
  local message="the subtitle file holds a style this tool cannot burn, so those lines are drawn as plain white text"

  # Act
  YAKITSUKE_TERMINAL=1 run yk_test_call yk_error "${message}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${#lines[@]}" -eq 2 ]]
  [[ "${lines[0]}" == "yakitsuke: the subtitle file holds a style this tool cannot burn, so those lines" ]]
  [[ "${lines[1]}" == "are drawn as plain white text" ]]
}

@test "an error sent to a pipe stays on one line, however long" {
  # Arrange
  local message="the subtitle file holds a style this tool cannot burn, so those lines are drawn as plain white text"

  # Act
  run yk_test_call yk_error "${message}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "yakitsuke: ${message}" ]]
}

@test "a word wider than 80 columns stays whole on its own line" {
  # Arrange
  local video="/Volumes/Archive/Films/The-Complete-Restored-Print-Of-Every-Reel-1968-To-1985.mkv"

  # Act
  YAKITSUKE_TERMINAL=1 run yk_test_call yk_info "Source: ${video}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "Source:" ]]
  [[ "${lines[1]}" == "        ${video}" ]]
}

@test "a doctor row stays on one line on a terminal, however long" {
  # Arrange
  local expected="sed                ok       /opt/homebrew/opt/gnu-sed/libexec/gnubin/sed, gnu 4.10"

  # Act
  YAKITSUKE_TERMINAL=1 run yk_test_call yk_doctor_row "sed" ok "/opt/homebrew/opt/gnu-sed/libexec/gnubin/sed, gnu 4.10"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "internal YK_ variables from the environment change nothing" {
  # Arrange
  local out="${WORK}/out"

  # Act
  YK_DISC_MINUTES=74 YK_OVERLAP=5 YK_SHARPEN=no run yk_test_run --output-dir "${out}" --dry-run "${CLIP}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Media:  80 min, 360000 sectors"* ]]
  [[ "${output}" == *", 30s overlap, "* ]]
  [[ "${output}" == *"sharpen yes"* ]]
}
