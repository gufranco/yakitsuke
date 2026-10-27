#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
minimum=${1:-100}
bash_bin=$(command -v bash)
# shellcheck disable=SC2016
if ! "${bash_bin}" -c '[ "${BASH_VERSINFO[0]}" -ge 4 ]' 2>/dev/null; then
  printf 'coverage: bashcov needs bash 4 or later, and %s is older. Install a newer bash first.\n' "${bash_bin}" >&2
  exit 1
fi
ruby_bin=$(command -v ruby)
bashcov_bin="${root}/scripts/bashcov-run.rb"
hashbang=$(printf '\043\041')

rm -rf "${root}/coverage"
mkdir -p "${root}/coverage"

wrapper_dir=$(mktemp -d "${TMPDIR:-/tmp}/yakitsuke-coverage-XXXXXX")
trap 'rm -rf "${wrapper_dir}"' EXIT
wrapper="${wrapper_dir}/bashcov-shell"
{
  printf '%s%s\n' "${hashbang}" "${bash_bin}"
  printf 'export BUNDLE_GEMFILE="%s/Gemfile"\n' "${root}"
  # shellcheck disable=SC2016
  printf 'exec "%s" -rbundler/setup "%s" --root "%s" --bash-path "%s" --command-name "run-$$-${RANDOM}" -- "$@"\n' \
    "${ruby_bin}" "${bashcov_bin}" "${root}" "${bash_bin}"
} >"${wrapper}"
chmod 0755 "${wrapper}"

YK_SHELL="${wrapper}" bats "${root}/test"

cd "${root}"
python3 scripts/coverage-gate.py '/(bin/yakitsuke|lib/[a-z]+\.sh)\Z' "${minimum}" coverage/.resultset.json
