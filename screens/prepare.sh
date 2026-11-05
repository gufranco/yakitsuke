#!/bin/sh
set -eu

: "${SCREENS_REPO:?}"
demo=/Users/Shared/demo
rm -rf "${demo}"
mkdir -p "${demo}/bin"
ffmpeg=$(command -v ffmpeg)
for candidate in /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg /usr/local/opt/ffmpeg-full/bin/ffmpeg; do
  if [ -x "${candidate}" ]; then
    ffmpeg="${candidate}"
  fi
done
"${ffmpeg}" -hide_banner -v error -y -f lavfi -i "testsrc2=size=1280x720:rate=24000/1001:duration=8" \
  -f lavfi -i "sine=frequency=330:sample_rate=48000:duration=8" -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
  -c:a aac -shortest "${demo}/holiday.mp4"
printf '1\n00:00:00,500 --> 00:00:03,500\nThe beach at sunrise.\n\n2\n00:00:04,000 --> 00:00:07,500\nEveryone made it this year.\n' >"${demo}/holiday.srt"
