#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
duplicates=$(cat "${root}"/bin/yakitsuke "${root}"/lib/*.sh |
  sed -n 's/^\([a-z_][a-z0-9_]*\)() {$/\1/p' | sort | uniq -d)
if [ -n "${duplicates}" ]; then
  printf 'function defined more than once:\n%s\n' "${duplicates}" >&2
  exit 1
fi

unprefixed=$(cat "${root}"/bin/yakitsuke "${root}"/lib/*.sh |
  grep -oE '[$][{]?[A-Z][A-Z0-9_]*' | sed 's/^[$][{]*//' | sort -u |
  grep -vE '^(YK|YAKITSUKE)_' | grep -vxE 'HOME|PATH|TMPDIR|ZSH_VERSION|HOMEBREW_PREFIX' || true)
if [ -n "${unprefixed}" ]; then
  printf 'environment variable without the YAKITSUKE_ prefix:\n%s\n' "${unprefixed}" >&2
  exit 1
fi

scrub="for yk_inherited in \$(env | sed -n 's/^\\(YK_[A-Za-z0-9_]*\\)=.*/\\1/p'); do"
if ! grep -qF "${scrub}" "${root}/bin/yakitsuke"; then
  printf 'bin/yakitsuke must clear every inherited YK_ variable before it starts\n' >&2
  exit 1
fi
