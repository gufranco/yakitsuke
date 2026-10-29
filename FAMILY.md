# kodougu 小道具: the family standard

The tools in the table below are one family of command-line tools, called kodougu (小道具), Japanese for the small tools of a craft. Each one is named for a single task in Japanese, and they look, read and behave alike, so a person who knows one already knows how to drive the others. This file is the contract they share.

| Member | What it does | Repository |
|:-------|:-------------|:-----------|
| fusho | Sends an encrypted message through any chat, using the recipient's published SSH keys | [gufranco/fusho](https://github.com/gufranco/fusho) |
| jimaku | Downloads subtitles for videos and saves them as UTF-8 | [gufranco/jimaku](https://github.com/gufranco/jimaku) |
| kakikomi | Writes a disk image to removable media, verified chunk by chunk, never mounted | [gufranco/kakikomi](https://github.com/gufranco/kakikomi) |
| kiyome | Overwrites a disk with five verified patterns and names any failing bit line | [gufranco/kiyome](https://github.com/gufranco/kiyome) |
| shiwake | Sorts the files of a folder into A to Z subfolders by their first letter | [gufranco/shiwake](https://github.com/gufranco/shiwake) |
| yakitsuke | Turns any video into Video CD images, split across discs, with readable subtitles | [gufranco/yakitsuke](https://github.com/gufranco/yakitsuke) |

## How a repository joins

Copy this file in unchanged, follow it, and add the repository to the table above in every member in the same task. Everything above the closing line is shared and must match across the members; with the members checked out side by side, this shows any drift:

```bash
for member in fusho jimaku kakikomi kiyome shiwake yakitsuke; do
  diff <(sed '/^---$/q' FAMILY.md) <(sed '/^---$/q' "../${member}/FAMILY.md")
done
```

A member that replaces a script in the owner's dotfiles, such as a zsh module, removes that script and its `source` line in the same task, and the dotfiles install the member instead: the Brewfile on macOS and `install.sh` on Linux.

A rule the owner sets for any member is written here and applied to every member, so they keep one style and one standard of quality. A rule that needs changing is changed in every member in the same task. The Homebrew tap that ships the members, [gufranco/homebrew-tap](https://github.com/gufranco/homebrew-tap), is not a member: it also carries tools and apps outside the family.

## Commands

Every tool answers the same three commands.

| Command | Prints | Exit |
|:--------|:-------|:-----|
| `help`, `-h`, `--help` | The help page on stdout | 0 |
| `version`, `-V`, `--version` | `<tool> X.Y.Z`, then one `key: value` context line | 0 |
| `doctor` | One row per dependency | 1 only when a required one is missing |

A file named `help`, `doctor` or `version` is still reachable by giving its path, such as `./help`.

## Help page

One plain page, in this order:

1. `<tool> - <one line saying what it does>`
2. `usage:`, one line per form, each with a short description, ending with `doctor`, `version` and `help`
3. Option sections: `options:`, or named groups such as `disc:` and `picture:` when there are many
4. `environment:`, only for settings that really come from the environment
5. `notes:`
6. `examples:`

No colour, no emoji, no bracketed level tags.

## Input

- Every setting is a long option. `--name value` and `--name=value` both work, and `--` ends the options.
- A yes or no setting that is asked about interactively has both forms, such as `--verify` and `--no-verify`.
- A setting may also come from an environment variable named after the tool, `<TOOL>_<SETTING>` in capitals, such as `KIYOME_PASSES=3` or `JIMAKU_LANGUAGE=pt-BR`. An option on the command line wins over the environment.
- No member reads a bare name such as `PASSES`, and none takes its internal variables from the environment: a member either assigns each one outright, or its entry point clears every inherited variable with its internal prefix, such as `JM_`, before anything runs. Test-only switches follow the same rule, such as `JIMAKU_TERMINAL` and `JIMAKU_TEST_SHELLS`. `scripts/check-names.sh` fails lint on any other name.
- Anything required and not given is asked for when stdin is a terminal: `Label [default]: ` on stderr, up to three tries for a required value.
- Without a terminal the tool never waits on a prompt. It stops with the usage hint below.
- A destructive step asks the person to type the device name: `Type disk4 to erase, or anything else to stop: `.
- With no arguments on a terminal, a tool with several jobs offers a numbered menu headed `What would you like to do?`; a tool with one job asks for its inputs directly.
- A member that takes a disk accepts its device, such as `/dev/disk4`, or any volume mounted from it, such as `/Volumes/USB`, and works on the whole disk behind the volume.

## Output

- Results and progress lines go to stdout. Prompts, diagnostics, and a progress line redrawn in place on a terminal go to stderr.
- Before a long or destructive run, a summary block states what is about to happen. Each label carries a colon and is padded to 8 columns; continuation lines are indented 8 spaces, and the block has a blank line above and below.

  ```text

  Image:  debian.img.xz
          xz, 1.4 GiB (1503238553 bytes)
  Target: /dev/disk4, 7.5 GiB, SANDISK CRUZER

  ```

- A long step shows one progress line: `<Verb> NNN%  <rate>  XmYYs left`. On a terminal it redraws in place; otherwise it prints once per 10 percent.
- The last line states the result in a full sentence, such as `Ejected. /dev/disk4 is safe to remove.`
- Every line printed to a terminal fits in 80 columns, the default width of Terminal, iTerm2, xterm and GNOME Terminal. A longer message wraps between words, and a summary line continues under its value. A single word wider than 80 columns, such as a long path, is printed whole on its own line. Sent to a pipe or a file, a message stays on one line, so a script can read it. `doctor` is exempt: its rows are technical, so each stays on one line at any width. Tests check that `help` and `version` stay within 80 columns.

## Diagnostics

| Kind | Form |
|:-----|:-----|
| Error | `<tool>: <message>` |
| Warning | `<tool>: warning: <message>` |
| Refusal before any harm | `<tool>: stopped: <reason>.` |
| Usage error | `<tool>: <problem>. run '<tool> help' for usage.` |
| Unknown option | `<tool>: unknown option '--x'. run '<tool> help' for usage.` |
| Option without its value | `<tool>: option '--x' needs a value. run '<tool> help' for usage.` |
| Bad value | `<tool>: --x must be <rule>, got: <value>` |
| Missing input without a terminal | `<tool>: no <thing> given. run '<tool> help' for usage.` |

- A message starts in lowercase, unless it starts with a name such as `FAT32` or `--passes`, and every sentence after the first does too.
- A sentence ends with a period. A `label: value` line ends with its value.
- Exit status is 0 on success and 1 on failure. An interrupt removes temporary files before the tool exits.

## doctor

```text
dd                 ok       /bin/dd
mcopy              missing  mtools, needed for Windows ISOs and format
```

Each row is `printf '%-18s %-8s %s\n'`: the dependency; `ok`, `missing` or `warn`; then the path when found, followed by a short note when one matters, or the remedy when not.

A row for a core tool, such as `awk`, `sed`, `dd`, `od`, `cmp`, `tr` or `date`, names its flavor and version after the path, so a bug report says which tools ran:

```text
awk                ok       /usr/bin/awk, bsd 20200816
dd                 ok       /usr/bin/dd, uutils 0.10.0
sed                ok       /opt/homebrew/opt/gnu-sed/libexec/gnubin/sed, gnu 4.10
```

The flavor is `gnu`, `uutils`, `bsd`, `mawk`, `busybox` or `unknown`. It comes from the tool's own `--version` answer, then from where it is installed, then from the system it runs on.

## Toolsets

Every member runs on the five toolsets in common use, and CI runs the whole suite on each:

| Toolset | What it is |
|:--------|:-----------|
| Linux, uutils | Ubuntu's default since 25.10: uutils coreutils, with GNU sed and mawk |
| Linux, GNU | GNU coreutils and gawk |
| macOS, native | Everything macOS ships, first on `PATH`: its BSD tools, bash 3.2, zsh, perl, openssl and the rest |
| macOS, Homebrew | Homebrew's current build of every tool macOS also ships, first on `PATH`: coreutils, findutils, gnu-sed, gawk, grep, diffutils, bash, zsh, and each member's own, such as openssl@3, curl, perl, libarchive, gzip, bzip2, libiconv or file-formula |
| macOS, uutils | Homebrew's uutils-coreutils, uutils-diffutils and uutils-findutils, first on `PATH` |

- A script uses only options all five accept. Where they differ, the code handles each one and a test covers it.
- Any tool macOS ships that Homebrew also builds in a newer version is tested in both: the macOS native toolset runs the system's copy, and the macOS Homebrew toolset runs Homebrew's. A member that starts calling such a tool adds its formula to the Homebrew leg in CI.
- `scripts/toolset.sh native`, `homebrew`, `gnu` or `uutils` prints the directories that put a toolset first on `PATH`; CI uses it, and so can a person reproducing a report.

## Documentation

- A README in English, Japanese, Simplified Chinese and Hong Kong Traditional Chinese, with the same sections in the same order: Quick start, with Prerequisites, Install and Verify; Usage; the tool's own topic sections; Portability; Development; License.
- The Hong Kong README is written Standard Chinese in Traditional characters with Hong Kong vocabulary, never colloquial Cantonese.
- The console sample at the top of every README is output copied from a real run. Only long data, such as ciphertext, may be cut short.
- A man page, `man/<tool>.1`.
- Completions for bash, zsh and fish under `completions/`.
- A test fails when the help page, the man page and the completions disagree on the options.

## Install

- `brew install gufranco/tap/<tool>` installs the tool, its man page and its completions.
- `make install` does the same from a checkout, under `PREFIX`, `~/.local` by default.
- A release updates the tap formula on its own: `formula.yml` asks the tap through a GitHub App, and the tap rewrites the formula's `url` and `sha256`. A version bump is never written into the tap by hand.

## Layout and tooling

Being adopted (as of 2026-10-28): fusho is moving to this layout, and `shfmt`, the single `scripts/coverage-gate.py` and the single `scripts/bashcov-run.rb` are being added to every member. Everything else here already holds in all six.

- `bin/<tool>` is the entry point and sources `lib/*.sh`. There is no build step; `share/` holds data files only.
- POSIX `sh` without `local`: every global carries the tool's internal prefix, such as `JM_`, and every function-scoped variable carries its function's prefix, such as `jm_fe_`. Variables are written `${name}`.
- `shfmt -i 2` formats every script, and `make lint` fails on unformatted code.
- Release tooling is pnpm, pinned through `packageManager` in `package.json`, running semantic-release. The release job installs it with `pnpm install --frozen-lockfile` and stops on `pnpm audit --audit-level high`. Dependabot updates the GitHub Actions and the release tooling weekly.
- Every action in a workflow is pinned to a full commit SHA, with its version in a trailing comment.
- Tests live in `test/`: `helpers.bash` for the shared helpers, `call.sh` to call one function, and `run-matrix.sh`, which runs the suites under each shell named in `<TOOL>_TEST_SHELLS`. CI runs one job per shell and toolset.
- These files are identical in every member apart from the tool's own name: `.editorconfig`, `.yamllint.yml`, `.github/actionlint.yaml`, `.github/dependabot.yml`, `.github/workflows/formula.yml`, `Gemfile`, `Gemfile.lock`, `.ruby-version`, `.simplecov`, `scripts/toolset.sh`, `scripts/coverage-gate.py`, `scripts/bashcov-run.rb` and `scripts/set-version.sh`.

## Quality

- 100% shell script in POSIX `sh`, working under `sh`, `dash`, `bash` and `zsh` on both Linux and macOS, each combination tested in CI.
- On macOS, `bash` and `zsh` each mean two shells, and all four are tested: the system's `/bin/bash`, which is bash 3.2, and `/bin/zsh`, next to Homebrew's current builds in `$(brew --prefix)/bin`. Code that runs under bash uses nothing bash 3.2 lacks.
- ShellCheck at zero errors and zero warnings.
- `bats` tests that drive the real tools, injecting faults only through small wrappers on `PATH`.
- 100 percent bashcov line coverage, gated in CI. Every `case` branch runs a command, because bashcov never counts a branch that holds only `;;`.
- Tests never write the member's version as a literal; they read it from `lib/core.sh`, so a release does not break them.
- A wait loop polls from milliseconds upward, never with a fixed `sleep 1`. On a runner without `timeout`, a one-second poll per `dd` made two members ten times slower.
- No comments in source, apart from tool directives and the `Arrange`, `Act`, `Assert` markers in tests.
- Make targets: `help`, `fmt`, `lint`, `test`, `coverage`, `check`, `install`. `make lint` runs `shfmt -i 2 -d` first; CI installs shfmt v3.14.1 from its release binary, checked against its SHA-256.
- Conventional commits pushed straight to `main`; there are no pull requests. semantic-release cuts the version.
- Before every push: `make lint`, the suites on both macOS builds, the suites on Ubuntu, and `make coverage`. CI repeats them; it does not replace them.
- A newer push cancels the CI still running for an older commit, but never a release in progress. Each test job carries `concurrency: ci-${{ github.ref }}-<job>-${{ strategy.job-index }}`, with the job's own name written out, and `cancel-in-progress: true`; `github.job` is empty when a job's concurrency group is evaluated, so it would put every job in one group, and the `release` and `formula` jobs each have their own group with `cancel-in-progress: false`. A workflow-level concurrency block is not used, since cancelling the whole run would stop a release halfway.
---

*Everything above this line is identical in every member. A member may add sections below it about its own state, and nothing may be added above it that the others do not also get.*

## The state of this repository

yakitsuke has one job, so a bare `yakitsuke` on a terminal asks for the video and the subtitle file directly. Its options are grouped by subject on the help page because there are many of them.

Gaps against the family standard (as of 2026-10-27): none.
