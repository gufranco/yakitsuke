#!/bin/sh
set -eu

repo="$(cd "$(dirname "$0")/.." && pwd)"
image="${YAKITSUKE_TEST_IMAGE:-ubuntu:26.04}"

docker run --rm \
  -v "${repo}:/repo" \
  -w /repo \
  -e YAKITSUKE_TEST_SHELLS="${YAKITSUKE_TEST_SHELLS:-}" \
  -e YAKITSUKE_TEST_RECORD="${YAKITSUKE_TEST_RECORD:-}" \
  "${image}" \
  sh -c '
    set -eu
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null
    apt-get install -y -qq --no-install-recommends \
      bats dash zsh mandoc file python3 ca-certificates ffmpeg mjpegtools vcdimager >/dev/null
    exec "$@"
  ' sh "$@"
