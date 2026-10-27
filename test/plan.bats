#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

@test "a film shorter than one disc gets one disc" {
  # Arrange
  local duration=600

  # Act
  run yk_test_call yk_disc_plan "${duration}" 4784 30

  # Assert
  [[ "${output}" == "0.000 600.000" ]]
}

@test "a long film is split evenly with the overlap repeated at each seam" {
  # Arrange
  local duration=7200

  # Act
  run yk_test_call yk_disc_plan "${duration}" 4784 30

  # Assert
  [[ "${lines[0]}" == "0.000 3615.000" ]]
  [[ "${lines[1]}" == "3585.000 3615.000" ]]
}

@test "an overlap as long as a disc is ignored" {
  # Arrange
  local overlap=50

  # Act
  run yk_test_call yk_disc_plan 100 40 "${overlap}"

  # Assert
  [[ "${#lines[@]}" -eq 3 ]]
  [[ "${lines[0]}" == "0.000 33.333" ]]
}

@test "a preview is taken from the middle" {
  # Arrange
  local seconds=10

  # Act
  run yk_test_call yk_preview_plan 100 "${seconds}"

  # Assert
  [[ "${output}" == "50.000 10.000" ]]
}

@test "a preview near the end moves back to fit" {
  # Arrange
  local seconds=60

  # Act
  run yk_test_call yk_preview_plan 100 "${seconds}"

  # Assert
  [[ "${output}" == "40.000 60.000" ]]
}

@test "a preview longer than the film covers the whole film" {
  # Arrange
  local seconds=200

  # Act
  run yk_test_call yk_preview_plan 100 "${seconds}"

  # Assert
  [[ "${output}" == "0.000 100.000" ]]
}
