#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  "${YK_TEST_FFMPEG}" -hide_banner -v error -y -f lavfi -i "color=c=red:s=320x240:r=25:d=30" \
    -f lavfi -i "color=c=blue:s=320x240:r=25:d=30" -filter_complex "[0][1]concat=n=2:v=1:a=0" \
    -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p "${BATS_FILE_TMPDIR:?}/cut.mp4"
}

@test "a full-frame HD source scales, converts to BT.601, sharpens and dithers" {
  # Arrange
  local expected="[0:v:0]fps=25,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv,format=yuv444p16,scale=352:288:flags=lanczos+accurate_rnd+full_chroma_int,zscale=t=bt709:m=bt470bg:p=bt470bg:r=tv,unsharp=5:5:0.4:5:5:0.0,zscale=c=center:d=error_diffusion,format=yuv420p,setsar=1[v]"

  # Act
  YK_ZSCALE=yes YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph

  # Assert
  [[ "${output}" == "${expected}" ]]
}

@test "a letterboxed picture is padded after sharpening, never before" {
  # Arrange
  local tail="unsharp=5:5:0.4:5:5:0.0,pad=352:240:0:52:color=black"

  # Act
  YK_STANDARD=film YK_ZSCALE=yes YK_PIC_W=1440 YK_PIC_H=612 YK_PAD_Y=234 run yk_test_call call_graph

  # Assert
  [[ "${output}" == *"scale=352:136:flags=lanczos+accurate_rnd+full_chroma_int,zscale=t=bt709:m=smpte170m:p=smpte170m:r=tv,${tail},zscale=c=center"* ]]
}

@test "every optional stage appears in order when asked for" {
  # Arrange
  local pre="[0:v:0]fieldmatch,decimate,crop=1920:800:0:140,setpts=PTS/1.042708,fps=25,fftdnoiz=sigma=1.5,crop=1066:800:427:0,"

  # Act
  YK_FIELD_MODE=ivtc YK_ACTIVE_H=800 YK_BORDER_Y=140 YK_SPEED=1.042708 YK_DENOISE=1.5 YK_FIT=crop \
    YK_CROP_W=1066 YK_CROP_H=800 YK_CROP_X=427 YK_CROP_Y=0 YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph

  # Assert
  [[ "${output}" == "${pre}"* ]]
}

@test "video interlace is deinterlaced with bwdif" {
  # Arrange
  local expected="[0:v:0]bwdif=mode=0:parity=-1:deint=0,fps=25,"

  # Act
  YK_FIELD_MODE=on YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph

  # Assert
  [[ "${output}" == "${expected}"* ]]
}

@test "without zscale the chain keeps to plain scaling" {
  # Arrange
  local expected="[0:v:0]fps=25,scale=352:288:flags=lanczos+accurate_rnd+full_chroma_int,unsharp=5:5:0.4:5:5:0.0,format=yuv420p,setsar=1[v]"

  # Act
  YK_ZSCALE=no YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph

  # Assert
  [[ "${output}" == "${expected}" ]]
}

@test "no sharpening and no colour conversion leave those stages out" {
  # Arrange
  local expected="[0:v:0]fps=25,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv,format=yuv444p16,scale=352:288:flags=lanczos+accurate_rnd+full_chroma_int,zscale=c=center:d=error_diffusion,format=yuv420p,setsar=1[v]"

  # Act
  YK_ZSCALE=yes YK_SHARPEN=no YK_COLOR_CONVERT=no YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph

  # Assert
  [[ "${output}" == "${expected}" ]]
}

@test "a tagged source matrix is used as it is" {
  # Arrange
  local expected="setparams=color_primaries=smpte170m:color_trc=bt709:colorspace=smpte170m"

  # Act
  YK_ZSCALE=yes YK_SRC_MATRIX=smpte170m YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph

  # Assert
  [[ "${output}" == *"${expected}"* ]]
  [[ "${output}" == *"zscale=t=bt709:m=bt470bg"* ]]
}

@test "an untagged SD source is assumed to be in the output matrix already" {
  # Arrange
  local expected="setparams=color_primaries=bt470bg:color_trc=bt709:colorspace=bt470bg"

  # Act
  YK_ZSCALE=yes YK_SRC_H=576 YK_SRC_MATRIX=unknown YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph

  # Assert
  [[ "${output}" == *"${expected}"* ]]
  [[ "${output}" != *"zscale=t=bt709"* ]]
}

@test "subtitles become a transparent layer overlaid after the picture chain" {
  # Arrange
  local layer="color=c=black@0:s=1440x1080:r=25:d=12.5,format=rgba,subtitles=filename=subtitles.ass:fontsdir=fonts:alpha=1:force_style='Fontsize=22',scale=352:288:flags=lanczos,format=yuva444p[sub]"

  # Act
  YK_SUB_MASTER=/m.ass YK_SUB_STYLE='Fontsize=22' YK_PIC_W=1440 YK_PIC_H=1080 run yk_test_call call_graph 12.5

  # Assert
  [[ "${output}" == *",format=yuv444p10[pic];${layer};[pic][sub]overlay=format=yuv444p10:eof_action=pass,"* ]]
}

@test "the audio chain resamples to 44.1 kHz stereo and keeps speed and loudness" {
  # Arrange
  local expected=$'atempo=1.042708\nloudnorm=I=-20\naresample=44100:resampler=soxr:precision=28:dither_method=triangular_hp\naformat=sample_fmts=s16:channel_layouts=stereo'

  # Act
  YK_SPEED=1.042708 YK_LOUDNORM="loudnorm=I=-20" run yk_test_call yk_audio_chain

  # Assert
  [[ "${output}" == "${expected}" ]]
}

@test "auto picks ffmpeg when mjpegtools is missing" {
  # Arrange
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/yk-enc.XXXXXX")"
  local farm
  farm="$(yk_test_farm mpeg2enc mplex)"

  # Act
  PATH="${farm}" YAKITSUKE_FFMPEG="${YK_TEST_FFMPEG}" run sh "${YK_TESTS_DIR}/call.sh" yk_resolve_encoder

  # Assert
  [[ "${output}" == "ffmpeg" ]]
  rm -rf "${WORK}"
}

@test "a seam is moved onto a scene change inside the window" {
  # Arrange
  local plan=$'0.000 28.000\n26.000 34.000'

  # Act
  YK_OVERLAP=2 run yk_test_call call_snap_plan "${BATS_FILE_TMPDIR}/cut.mp4" "${plan}" 40 5 60

  # Assert
  [[ "${output}" == $'0.000 30.000\n28.000 32.000' ]]
}

@test "a snapped seam that would overfill a disc keeps the even split" {
  # Arrange
  local plan=$'0.000 28.000\n26.000 34.000'

  # Act
  YK_OVERLAP=2 run yk_test_call call_snap_plan "${BATS_FILE_TMPDIR}/cut.mp4" "${plan}" 29 5 60

  # Assert
  [[ "${output}" == "${plan}" ]]
}

@test "a seam with no scene change nearby stays where it was" {
  # Arrange
  local plan=$'0.000 10.000\n8.000 52.000'

  # Act
  YK_OVERLAP=2 run yk_test_call call_snap_plan "${BATS_FILE_TMPDIR}/cut.mp4" "${plan}" 60 3 60

  # Assert
  [[ "${output}" == "${plan}" ]]
}

@test "a chapter mark snaps to the scene change" {
  # Arrange
  local start=-32

  # Act
  YK_CHAPTERS=1 YK_SCENE_SNAP=15 run yk_test_call yk_entry_points "${BATS_FILE_TMPDIR}/cut.mp4" 90 "${start}"

  # Assert
  [[ "${output}" == '      <entry id="entry-000">62</entry>' ]]
}

@test "a snapped chapter mark past the end of the disc keeps the even mark" {
  # Arrange
  local start=-31.5

  # Act
  YK_CHAPTERS=1 YK_SCENE_SNAP=15 run yk_test_call yk_entry_points "${BATS_FILE_TMPDIR}/cut.mp4" 62 "${start}"

  # Assert
  [[ "${output}" == '      <entry id="entry-000">60</entry>' ]]
}

@test "chapter marks keep the even spacing when snapping is off" {
  # Arrange
  local span=200

  # Act
  YK_CHAPTERS=1 YK_SCENE_SNAP=0 run yk_test_call yk_entry_points "${BATS_FILE_TMPDIR}/cut.mp4" "${span}" 0

  # Assert
  [[ "${lines[0]}" == '      <entry id="entry-000">60</entry>' ]]
  [[ "${lines[2]}" == '      <entry id="entry-002">180</entry>' ]]
}

@test "the VCD XML escapes the stream path" {
  # Arrange
  local xml="${BATS_TMPDIR}/yk-$$.xml"

  # Act
  yk_test_call yk_write_xml "${xml}" "/tmp/a&b<c>.mpg" LABEL ALBUM 2 1 ""
  run cat "${xml}"

  # Assert
  [[ "${output}" == *'<sequence-item src="/tmp/a&amp;b&lt;c&gt;.mpg" id="sequence-00">'* ]]
  [[ "${output}" == *"<volume-count>2</volume-count>"* ]]
  rm -f "${xml}"
}
