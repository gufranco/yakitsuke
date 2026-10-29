#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  yk_test_media "${BATS_FILE_TMPDIR:?}/pal.mp4" 4 320x240 25
}

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/yk-json.XXXXXX")"
  WORK="$(cd "${WORK}" && pwd -P)"
  OUT="${WORK}/out"
  CLIP="$(cd "${BATS_FILE_TMPDIR}" && pwd -P)/pal.mp4"
}

teardown() {
  rm -rf "${WORK}"
}

sectors_of() {
  local bytes
  bytes="$(wc -c <"$1")"
  printf '%s\n' "$((bytes / 2352))"
}

@test "--json prints the images a run wrote as one JSON object" {
  # Arrange
  local clip="${CLIP}"

  # Act
  run yk_test_run --json --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  local sectors
  sectors="$(sectors_of "${OUT}/pal_disc1.bin")"
  [[ "${output}" == "{\"source\":\"${clip}\",\"output_dir\":\"${OUT}\",\"dry_run\":false,\"capacity\":360000,\"discs\":[{\"number\":1,\"bin\":\"${OUT}/pal_disc1.bin\",\"cue\":\"${OUT}/pal_disc1.cue\",\"sectors\":${sectors},\"kept\":false}]}" ]]
}

@test "--json with --dry-run lists the planned discs and writes nothing" {
  # Arrange
  local clip="${CLIP}"

  # Act
  run yk_test_run --json --dry-run --output-dir "${OUT}" "${clip}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "{\"source\":\"${clip}\",\"output_dir\":\"${OUT}\",\"dry_run\":true,\"capacity\":360000,\"discs\":[{\"number\":1,\"start\":0.000,\"seconds\":4.000,\"bin\":\"${OUT}/pal_disc1.bin\"}]}" ]]
  [[ ! -e "${OUT}/pal_disc1.bin" ]]
}

@test "--json with --resume marks an image it kept" {
  # Arrange
  yk_test_run --output-dir "${OUT}" "${CLIP}" >/dev/null
  local sectors
  sectors="$(sectors_of "${OUT}/pal_disc1.bin")"

  # Act
  run yk_test_run --json --resume --output-dir "${OUT}" "${CLIP}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"\"discs\":[{\"number\":1,\"bin\":\"${OUT}/pal_disc1.bin\",\"cue\":\"${OUT}/pal_disc1.cue\",\"sectors\":${sectors},\"kept\":true}]}" ]]
}
