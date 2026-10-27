#!/bin/sh
set -eu

usage() {
  printf 'usage: sh scripts/toolset.sh native|gnu|uutils [farm-dir]\n' >&2
  exit 1
}

[ "$#" -ge 1 ] || usage
toolset="$1"
farm="${2:-${TMPDIR:-/tmp}/toolset-${toolset}}"
os="$(uname -s)"

darwin_dirs() {
  for formula in "$@"; do
    for dir in "${prefix}/opt/${formula}/libexec/gnubin" "${prefix}/opt/${formula}/libexec/uubin"; do
      if [ -d "${dir}" ]; then
        printf '%s\n' "${dir}"
      fi
    done
  done
}

linux_gnu_farm() {
  mkdir -p "${farm}"
  for tool in /usr/bin/gnu*; do
    [ -x "${tool}" ] || continue
    ln -sf "${tool}" "${farm}/${tool#/usr/bin/gnu}"
  done
  gawk_path="$(command -v gawk)"
  ln -sf "${gawk_path}" "${farm}/awk"
  printf '%s\n' "${farm}"
}

linux_uutils_farm() {
  mkdir -p "${farm}"
  for tool in /usr/lib/cargo/bin/coreutils/*; do
    [ -x "${tool}" ] || continue
    ln -sf "${tool}" "${farm}/${tool##*/}"
  done
  printf '%s\n' "${farm}"
}

prefix=""
if [ "${os}" = Darwin ]; then
  prefix="$(brew --prefix)"
fi

case "${toolset}:${os}" in
native:*) ;;
gnu:Darwin)
  darwin_dirs coreutils findutils gnu-sed gawk grep
  printf '%s\n' "${prefix}/opt/diffutils/bin"
  ;;
gnu:Linux) linux_gnu_farm ;;
uutils:Darwin) darwin_dirs uutils-coreutils uutils-diffutils uutils-findutils ;;
uutils:Linux) linux_uutils_farm ;;
*) usage ;;
esac
