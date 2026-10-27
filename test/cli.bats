#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  yk_test_media "${BATS_FILE_TMPDIR:?}/clip.mp4" 2 320x240 25
  yk_test_srt "${BATS_FILE_TMPDIR}/clip.srt" 1
}

setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/yk-cli.XXXXXX")"
  CLIP="${BATS_FILE_TMPDIR}/clip.mp4"
}

teardown() {
  rm -rf "${WORK}"
}

@test "help prints the usage page" {
  # Arrange
  local first="yakitsuke - burn any video onto Video CD: VCD 2.0 BIN/CUE images, split across discs"

  # Act
  run yk_test_run help

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "${first}" ]]
}

@test "version prints the program, its version and the platform" {
  # Arrange
  local platform
  platform="$(uname -sr)"

  # Act
  run yk_test_run --version

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" =~ ^yakitsuke\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
  [[ "${lines[1]}" == "platform: ${platform}" ]]
}

@test "doctor passes when every required tool is installed" {
  # Arrange
  local expected="vcdxbuild"

  # Act
  run yk_test_run doctor

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"${expected}"*" ok "* ]]
  [[ "${output}" == *"ffmpeg subtitles   ok"* ]]
}

@test "doctor fails and says how to install vcdimager when it is missing" {
  # Arrange
  local farm
  farm="$(yk_test_farm vcdxbuild)"

  # Act
  run yk_test_run_path "${farm}" doctor

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"vcdxbuild          missing  brew install vcdimager, or apt install vcdimager"* ]]
}

@test "doctor still passes without the optional mjpegtools" {
  # Arrange
  local farm
  farm="$(yk_test_farm mpeg2enc mplex)"

  # Act
  run yk_test_run_path "${farm}" doctor

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"mpeg2enc           missing  mjpegtools, the better encoder"* ]]
}

@test "doctor reports the ffmpeg filters as missing when there is no ffmpeg" {
  # Arrange
  local farm
  farm="$(yk_test_farm ffmpeg ffprobe)"

  # Act
  YAKITSUKE_FFMPEG="" HOMEBREW_PREFIX="${WORK}/none" run yk_test_run_path "${farm}" doctor

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ffmpeg subtitles   missing"* ]]
  [[ "${output}" == *"ffmpeg zscale      missing"* ]]
}

@test "no video outside a terminal is an error with a hint" {
  # Arrange
  local expected="yakitsuke: no video given. run 'yakitsuke help' for usage."

  # Act
  run yk_test_run </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "in a terminal the video and subtitles are asked for" {
  # Arrange
  local answers
  answers="$(printf '%s\n%s\n' "${CLIP}" "${BATS_FILE_TMPDIR}/clip.srt")"

  # Act
  YK_INTERACTIVE=1 run yk_test_run --dry-run <<<"${answers}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Video file: Subtitle file, Enter for none: "* ]]
  [[ "${output}" == *"subtitles burned in: 1 lines"* ]]
}

@test "three empty answers for the video give up with a hint" {
  # Arrange
  local answers=$'\n\n\n'

  # Act
  YK_INTERACTIVE=1 run yk_test_run <<<"${answers}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"yakitsuke: no video given. run 'yakitsuke help' for usage."* ]]
}

@test "end of input while asking stops the run" {
  # Arrange
  local empty=""

  # Act
  YK_INTERACTIVE=1 run yk_test_run < <(printf '%s' "${empty}")

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "Video file: " ]]
}

@test "end of input at the subtitle question stops the run" {
  # Arrange
  local answers
  answers="$(printf '%s\n' "${CLIP}")"

  # Act
  YK_INTERACTIVE=1 run yk_test_run < <(printf '%s' "${answers}")

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "Video file: Subtitle file, Enter for none: " ]]
}

@test "an unknown long option is rejected" {
  # Arrange
  local option="--bogus"

  # Act
  run yk_test_run "${option}" "${CLIP}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: unknown option '--bogus'. run 'yakitsuke help' for usage." ]]
}

@test "an unknown option given with a value is rejected" {
  # Arrange
  local option="--bogus=1"

  # Act
  run yk_test_run "${option}" "${CLIP}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: unknown option '--bogus'. run 'yakitsuke help' for usage." ]]
}

@test "an unknown short option is rejected" {
  # Arrange
  local option="-x"

  # Act
  run yk_test_run "${option}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: unknown option '-x'. run 'yakitsuke help' for usage." ]]
}

@test "an option missing its value is rejected" {
  # Arrange
  local option="--overlap"

  # Act
  run yk_test_run "${option}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: option '--overlap' needs a value. run 'yakitsuke help' for usage." ]]
}

@test "a third positional argument is rejected" {
  # Arrange
  local extra="third"

  # Act
  run yk_test_run "${CLIP}" sub.srt "${extra}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: unexpected extra argument 'third'. run 'yakitsuke help' for usage." ]]
}

@test "a third positional argument after -- is rejected too" {
  # Arrange
  local extra="--third"

  # Act
  run yk_test_run -- "${CLIP}" sub.srt "${extra}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: unexpected extra argument '--third'. run 'yakitsuke help' for usage." ]]
}

@test "a file named like an option is read after --" {
  # Arrange
  cp -f "${CLIP}" "${WORK}/--odd.mp4"
  cd "${WORK}" || return 1

  # Act
  run yk_test_run --dry-run -- --odd.mp4

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Source: --odd.mp4"* ]]
}

@test "every invalid value is named in the error" {
  # Arrange
  local -a cases=(
    "--disc-minutes=x|--disc-minutes must be a whole number of minutes, got: x"
    "--disc-minutes=0|--disc-minutes must be at least 1, got: 0"
    "--overlap=-1|--overlap must be a whole number of seconds, got: -1"
    "--scene-snap=a|--scene-snap must be a whole number of seconds, got: a"
    "--chapters=1.5|--chapters must be a whole number of minutes, got: 1.5"
    "--preview=x|--preview must be a whole number of seconds, got: x"
    "--audio-track=a|--audio-track must be a whole number of stream index, got: a"
    "--sub-track=b|--sub-track must be a whole number of stream index, got: b"
    "--deinterlace=maybe|--deinterlace must be auto, on, ivtc or off, got: maybe"
    "--borders=x|--borders must be auto or off, got: x"
    "--sub-color=red|--sub-color must be auto, white or yellow, got: red"
    "--sub-box=x|--sub-box must be auto, always or never, got: x"
    "--encoder=x264|--encoder must be auto, mpeg2enc or ffmpeg, got: x264"
    "--sub-offset=1.2.3|--sub-offset must be a number of seconds, got: 1.2.3"
    "--denoise=hard|--denoise must be off or an fftdnoiz sigma such as 1.5, got: hard"
  )
  local entry failures=0

  # Act
  for entry in "${cases[@]}"; do
    run yk_test_run "${entry%%|*}" "${CLIP}"
    [[ "${status}" -eq 1 && "${output}" == "yakitsuke: ${entry#*|}" ]] || failures=$((failures + 1))
  done

  # Assert
  [[ "${failures}" -eq 0 ]]
}

@test "force and resume together are refused" {
  # Arrange
  local -a options=(--force --resume)

  # Act
  run yk_test_run "${options[@]}" "${CLIP}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: --force and --resume contradict each other; pick one." ]]
}

@test "a missing source is named" {
  # Arrange
  local missing="${WORK}/absent.mp4"

  # Act
  run yk_test_run "${missing}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: source not found: ${missing}" ]]
}

@test "a missing subtitle file is named" {
  # Arrange
  local missing="${WORK}/absent.srt"

  # Act
  run yk_test_run "${CLIP}" "${missing}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: subtitle file not found: ${missing}" ]]
}

@test "no ffmpeg at all points at doctor" {
  # Arrange
  local farm
  farm="$(yk_test_farm ffmpeg)"

  # Act
  YAKITSUKE_FFMPEG="" HOMEBREW_PREFIX="${WORK}/none" run yk_test_run_path "${farm}" "${CLIP}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: ffmpeg is not installed. run 'yakitsuke doctor' for what is missing." ]]
}

@test "subtitles without an ffmpeg that has libass explain the fix" {
  # Arrange
  yk_test_shim ffmpeg "case \"\$*\" in *filter=subtitles*) exit 0 ;; esac
exec \"\$REAL\" \"\$@\""

  # Act
  YAKITSUKE_FFMPEG="" HOMEBREW_PREFIX="${WORK}/none" run yk_test_run "${CLIP}" "${BATS_FILE_TMPDIR}/clip.srt"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"no ffmpeg with the 'subtitles' filter was found"* ]]
  [[ "${output}" == *"brew install ffmpeg-full, or point YAKITSUKE_FFMPEG at a suitable build"* ]]
}

@test "a missing ffprobe stops the run" {
  # Arrange
  local farm
  mkdir -p "${WORK}/ff"
  ln -s "${YK_TEST_FFMPEG}" "${WORK}/ff/ffmpeg"
  farm="$(yk_test_farm ffprobe)"

  # Act
  YAKITSUKE_FFMPEG="${WORK}/ff/ffmpeg" run yk_test_run_path "${farm}" "${CLIP}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: ffprobe is not installed." ]]
}

@test "asking for mpeg2enc without mjpegtools stops the run" {
  # Arrange
  local farm
  farm="$(yk_test_farm mpeg2enc)"

  # Act
  YAKITSUKE_FFMPEG="${YK_TEST_FFMPEG}" run yk_test_run_path "${farm}" --encoder mpeg2enc "${CLIP}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: --encoder mpeg2enc needs mpeg2enc and mplex from mjpegtools." ]]
}

@test "a missing vcdxbuild stops the run before any work" {
  # Arrange
  local farm
  farm="$(yk_test_farm vcdxbuild)"

  # Act
  YAKITSUKE_FFMPEG="${YK_TEST_FFMPEG}" run yk_test_run_path "${farm}" "${CLIP}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "yakitsuke: missing tool: vcdxbuild. run 'yakitsuke doctor' for how to install it." ]]
}

@test "the tool runs by its bare name from inside its own folder" {
  # Arrange
  local -a shell_words
  read -r -a shell_words <<<"${YK_SHELL:-sh}"
  cd "${REPO_DIR}/bin" || return 1

  # Act
  PATH="${REPO_DIR}/bin:${PATH}" run "${shell_words[@]}" yakitsuke version

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" =~ ^yakitsuke\ [0-9] ]]
}

@test "every flag is accepted and shows up in the plan" {
  # Arrange
  local -a flags=(--cd74 --cd90 --cd80 --film --crop --letterbox --no-sharpen --sharpen --no-color-convert --title "Night Film" --sub-style "Fontsize=20" --dry-run)

  # Act
  run yk_test_run "${flags[@]}" "${CLIP}" "${BATS_FILE_TMPDIR}/clip.srt"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Target: FILM Video CD, 352x240 at 24000/1001 fps"* ]]
  [[ "${output}" == *", letterbox"* ]]
  [[ "${output}" == *"sharpen yes"* ]]
  [[ "${output}" == *"Media:  80 min, 360000 sectors"* ]]
}


help_options() {
  local page
  page="$(yk_test_run help)" || return 1
  awk '/^  --/ { for (i = 1; i <= NF; i++) if (match($i, /^--[a-z0-9][a-z0-9-]*/)) { name = substr($i, RSTART, RLENGTH); if (!seen[name]++) print name } }' <<<"${page}"
}

option_drift() {
  local option name man_form missing="" listed completed
  listed="$(help_options)" || return 1
  completed="$(grep -oE -- "--[a-z0-9][a-z0-9-]*" "${REPO_DIR}/completions/yakitsuke.bash")" || return 1
  for option in ${listed}; do
    name="${option#--}"
    man_form="\\-\\-${name//-/\\-}"
    grep -qF -- "${man_form}" "${REPO_DIR}/man/yakitsuke.1" || missing="${missing} man:${option}"
    grep -qE -- "(^|[ \"])${option}( |\"|$)" "${REPO_DIR}/completions/yakitsuke.bash" || missing="${missing} bash:${option}"
    grep -qE -- "[')]${option}\\[" "${REPO_DIR}/completions/_yakitsuke" || missing="${missing} zsh:${option}"
    grep -qE -- "-l ${name} " "${REPO_DIR}/completions/yakitsuke.fish" || missing="${missing} fish:${option}"
  done
  for option in ${completed}; do
    grep -qx -- "${option}" <<<"${listed}" || missing="${missing} help:${option}"
  done
  printf '%s' "${missing}"
}

@test "help, man page and completions list the same options" {
  # Arrange
  local expected=""

  # Act
  run option_drift

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "the man page passes mandoc lint" {
  # Arrange
  local page="${REPO_DIR}/man/yakitsuke.1"

  # Act
  run mandoc -T lint "${page}"

  # Assert
  [[ "${status}" -eq 0 ]]
}
