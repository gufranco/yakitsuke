#!/bin/sh
set -eu

version=${1:?version required}
root=$(cd "$(dirname "$0")/../.." && pwd)
core="${root}/lib/core.sh"

if ! grep -q '^YAKITSUKE_VERSION=' "${core}"; then
  printf 'no YAKITSUKE_VERSION assignment found in %s\n' "${core}" >&2
  exit 1
fi

tmp=$(mktemp "${TMPDIR:-/tmp}/yakitsuke-version-XXXXXX")
sed "s/^YAKITSUKE_VERSION=\".*\"$/YAKITSUKE_VERSION=\"${version}\"/" "${core}" >"${tmp}"
cat "${tmp}" >"${core}"
rm -f "${tmp}"

reported=$("${root}/bin/yakitsuke" --version)
printf 'version set to %s\n' "${reported}"
