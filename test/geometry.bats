#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

@test "a 25 fps source becomes PAL" {
  # Arrange
  local rate="25/1"

  # Act
  run yk_test_call call_standard "${rate}"

  # Assert
  [[ "${output}" == "pal 288 25 3 1" ]]
}

@test "a 50 fps source becomes PAL" {
  # Arrange
  local rate="50/1"

  # Act
  run yk_test_call call_standard "${rate}"

  # Assert
  [[ "${output}" == "pal 288 25 3 1" ]]
}

@test "a 23.976 fps film stays film instead of being duplicated to 29.97" {
  # Arrange
  local rate="24000/1001"

  # Act
  run yk_test_call call_standard "${rate}"

  # Assert
  [[ "${output}" == "film 240 24000/1001 1 1" ]]
}

@test "a 24 fps film stays film" {
  # Arrange
  local rate="24"

  # Act
  run yk_test_call call_standard "${rate}"

  # Assert
  [[ "${output}" == "film 240 24000/1001 1 1" ]]
}

@test "a 29.97 fps source becomes NTSC" {
  # Arrange
  local rate="30000/1001"

  # Act
  run yk_test_call call_standard "${rate}"

  # Assert
  [[ "${output}" == "ntsc 240 30000/1001 4 1" ]]
}

@test "film forced to PAL is sped up rather than given duplicate frames" {
  # Arrange
  local rate="24000/1001"

  # Act
  run yk_test_call call_standard "${rate}" pal

  # Assert
  [[ "${output}" == "pal 288 25 3 1.042708" ]]
}

@test "a forced standard wins over the source rate" {
  # Arrange
  local rate="25/1"

  # Act
  run yk_test_call call_standard "${rate}" ntsc

  # Assert
  [[ "${output}" == "ntsc 240 30000/1001 4 1" ]]
}

@test "a widescreen picture is letterboxed across the full canvas width" {
  # Arrange
  local dar="2.35"

  # Act
  run yk_test_call yk_fit_geometry letterbox 1920 818 "${dar}"

  # Assert
  [[ "${output}" == "0 0 0 0 1440 612 0 234" ]]
}

@test "a narrow picture is pillarboxed across the full canvas height" {
  # Arrange
  local dar="1.0"

  # Act
  run yk_test_call yk_fit_geometry letterbox 1000 1000 "${dar}"

  # Assert
  [[ "${output}" == "0 0 0 0 1080 1080 180 0" ]]
}

@test "crop fills the frame by cutting the sides of a wide picture" {
  # Arrange
  local dar="1.7777777778"

  # Act
  run yk_test_call yk_fit_geometry crop 1920 1080 "${dar}"

  # Assert
  [[ "${output}" == "1440 1080 240 0 1440 1080 0 0" ]]
}

@test "crop fills the frame by cutting top and bottom of a tall picture" {
  # Arrange
  local dar="1.0"

  # Act
  run yk_test_call yk_fit_geometry crop 1000 1000 "${dar}"

  # Assert
  [[ "${output}" == "1000 750 0 125 1440 1080 0 0" ]]
}

@test "display aspect honours the sample aspect ratio" {
  # Arrange
  local sar="32:27"

  # Act
  run yk_test_call yk_display_aspect 720 480 "${sar}"

  # Assert
  [[ "${output}" == "1.7777777778" ]]
}

@test "display aspect treats an unknown sample aspect as square" {
  # Arrange
  local sar="N/A"

  # Act
  run yk_test_call yk_display_aspect 640 480 "${sar}"

  # Assert
  [[ "${output}" == "1.3333333333" ]]
}
