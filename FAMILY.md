# kodougu 小道具: the family standard

The tools in the table below are one family of command-line tools, called kodougu (小道具), Japanese for the small tools of a craft. Each one is named for a single task in Japanese, and they look, read and behave alike, so a person who knows one already knows how to drive the others.

Two files carry the family, and every member implements everything both say:

- `FAMILY.md`, this file, holds everything the members share. It is the same, byte for byte, in every member.
- [`AGENTS.md`](AGENTS.md) holds only what is exclusive to its own repository: its layout, its names, the rules of its own domain, its release details and its open gaps. Every member's `AGENTS.md` has the same headings. A rule that would serve more than one member belongs here instead.

Nothing about the family lives anywhere else, so anyone with the repositories has all of it. A coding agent's own instruction file in a member only imports `AGENTS.md`.

| Member | What it does | Repository |
|:-------|:-------------|:-----------|
| fusho | Sends an encrypted message through any chat, using the recipient's published SSH keys | [gufranco/fusho](https://github.com/gufranco/fusho) |
| jimaku | Downloads subtitles for videos and saves them as UTF-8 | [gufranco/jimaku](https://github.com/gufranco/jimaku) |
| kakikomi | Writes a disk image to removable media, verified chunk by chunk, never mounted | [gufranco/kakikomi](https://github.com/gufranco/kakikomi) |
| kiyome | Overwrites a disk with five verified patterns and names any failing bit line | [gufranco/kiyome](https://github.com/gufranco/kiyome) |
| shiwake | Sorts the files of a folder into A to Z subfolders by their first letter | [gufranco/shiwake](https://github.com/gufranco/shiwake) |
| yakitsuke | Turns any video into Video CD images, split across discs, with readable subtitles | [gufranco/yakitsuke](https://github.com/gufranco/yakitsuke) |

## How a repository joins

Copy this file in unchanged, write an `AGENTS.md` with the same headings as the other members', follow both, and add the repository to the table above in every member in the same task. With the members checked out side by side, this shows any drift:

```bash
for member in fusho jimaku kakikomi kiyome shiwake yakitsuke; do
  cmp FAMILY.md "../${member}/FAMILY.md"
done
```

A new member also needs, in the same task:

1. The identical files listed under Layout and tooling, and a `ci.yml` modeled on an existing member's, with its own jobs, the shared schedule and the shared concurrency group.
2. A public repository, so Actions minutes and the scheduled runs cost nothing, with Dependabot alerts on and the Renovate GitHub App, which the owner keeps installed on every repository.
3. The `TAP_APP_ID` and `TAP_APP_PRIVATE_KEY` secrets, which `formula.yml` uses to reach the tap.
4. In the tap, `Formula/<tool>.rb`, and the tool's name in the allowlist of the tap's `formula-bump.yml`.
5. Its name in the `for member in` loop above, in every member.

A member that replaces a script in the owner's dotfiles, such as a zsh module, removes that script and its `source` line in the same task, and the dotfiles install the member instead: the Brewfile on macOS, and on Linux `install.sh`, which clones the member and runs `make install`.

A rule the owner sets for any member is written here and applied to every member, so they keep one style and one standard of quality. A rule that needs changing is changed in every member in the same task. The family is also the owner's reference standard: another of his projects that is refactored adopts these rules wherever they apply.

The Homebrew tap that ships the members, [gufranco/homebrew-tap](https://github.com/gufranco/homebrew-tap), is not a member: it also carries tools and apps outside the family.

## Commands

Every tool answers the same three commands.

| Command | Prints | Exit |
|:--------|:-------|:-----|
| `help`, `-h`, `--help` | The help page on stdout | 0 |
| `version`, `-V`, `--version` | `<tool> X.Y.Z`, then one `key: value` context line | 0 |
| `doctor` | One row per dependency | 1 only when a required one is missing |

No other spelling of these commands exists. A file named `help`, `doctor` or `version` is still reachable by giving its path, such as `./help`. An action is always a command, such as `kakikomi format`, never an option.

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
- A member that takes a disk accepts its device, such as `/dev/disk4`, or any volume mounted from it, such as `/Volumes/USB`, and works on the whole disk behind the volume. Its README shows both forms.

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
- Every line printed to a terminal fits in 80 columns, the default width of Terminal, iTerm2, xterm and GNOME Terminal. A longer message wraps between words, and a summary line continues under its value. A single word wider than 80 columns, such as a long path, is printed whole on its own line. Sent to a pipe or a file, a message stays on one line, so a script can read it. `doctor` is exempt: its rows are technical, so each stays on one line at any width.
- Text that holds a path or any other value of unbounded length goes through the member's say, error and warning helpers, which do the wrapping. `<TOOL>_TERMINAL=1` makes a test behave as a terminal, and `test/width.bats` checks that `help` and `version` stay within 80 columns.
- A command whose result a script would read offers `--json`, which prints that result as one JSON object on stdout in place of the text form.

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

The flavor is `gnu`, `uutils`, `bsd`, `mawk`, `busybox` or `unknown`. It comes from the tool's own `--version` answer, then from where it is installed, then from the system it runs on. A new dependency gets its `doctor` row, with its flavor when it is a core tool, in the same change.

## Toolsets

Every member runs on the five toolsets in common use, and CI runs the whole suite on each:

| Toolset | What it is |
|:--------|:-----------|
| Linux, uutils | Ubuntu's default since 25.10: uutils coreutils, with GNU sed and mawk |
| Linux, GNU | GNU coreutils and gawk |
| macOS, native | Everything macOS ships, first on `PATH`: its BSD tools, bash 3.2, zsh, perl, openssl and the rest |
| macOS, Homebrew | Homebrew's current build of every tool macOS also ships, first on `PATH`: coreutils, findutils, gnu-sed, gawk, grep, diffutils, bash, zsh, and each member's own, such as openssl@3, curl, perl, libarchive, gzip, bzip2, libiconv or file-formula |
| macOS, uutils | Homebrew's uutils-coreutils, uutils-diffutils and uutils-findutils, first on `PATH` |

- A script uses only options all five accept. Where they differ, the code handles each one and a test covers it. A change that passes on one toolset only is not done.
- Any tool macOS ships that Homebrew also builds in a newer version is tested in both: the macOS native toolset runs the system's copy, and the macOS Homebrew toolset runs Homebrew's. A member that starts calling such a tool adds its formula to the Homebrew leg in CI.
- `scripts/toolset.sh native`, `homebrew`, `gnu` or `uutils` prints the directories that put a toolset first on `PATH`. CI uses it, and a report is reproduced by putting the reporter's toolset first: `export PATH="$(sh scripts/toolset.sh gnu | paste -sd: -):$PATH"`.

## Safety

- A file is written to a temporary file beside it, then renamed over it with `mv -f`, so an interrupted run never leaves half a file. A file the person did not name is never overwritten, and a step that fails leaves the original exactly as it was.
- Files are found with shell globs, never by parsing `ls` or `find` output, so any name, with spaces, brackets or a newline, passes through intact.
- An external command runs once per batch of items, never once per item, such as one `mv` for a batch of files.
- Every external dependency works with the version the current Ubuntu LTS packages and with the current one Homebrew ships. An optional flag is detected once per run, from the tool's own `--help` or `--version`, and used only when it is there.
- A tuned default, such as an encoder setting or a buffer size, is chosen by measurement. A change to one records, in its commit body, a measurement that beats the current value.

## Documentation

- A README in English, Japanese, Simplified Chinese and Hong Kong Traditional Chinese, with the same sections in the same order: Quick start, with Prerequisites, Install and Verify; Usage; the tool's own topic sections; Portability; Development; License.
- The Hong Kong README is written Standard Chinese in Traditional characters with Hong Kong vocabulary, never colloquial Cantonese.
- The console sample at the top of every README is output copied from a real run. Only long data, such as ciphertext, may be cut short.
- A man page, `man/<tool>.1`.
- Completions for bash, zsh and fish under `completions/`.
- A new option goes into the help page, the man page and all three completions in the same commit, and a test fails when they disagree.

## Install

- `brew install gufranco/tap/<tool>` installs the tool, its man page and its completions.
- `make install` does the same from a checkout, under `PREFIX`, `~/.local` by default.
- The formula lives in the tap as `Formula/<tool>.rb`. Its `install` block decides which files reach users, so a new installed file or a new dependency needs a matching change there.
- A release updates the formula on its own: `formula.yml` asks the tap through a GitHub App, and the tap rewrites the formula's `url` and `sha256`. A version bump is never written into the tap by hand. The tap never moves a formula back to an older tag, so two releases close together are safe in any order.
- No member is published to any other package registry.

## Layout and tooling

- `bin/<tool>` is the entry point and sources `lib/*.sh`. There is no build step; `share/` holds data files only. `lib/state.sh` declares every global, and `lib/core.sh` holds `<TOOL>_VERSION`.
- POSIX `sh` without `local`: every global carries the tool's internal prefix, such as `JM_`, and every function-scoped variable carries its function's prefix, such as `jm_fe_`. Variables are written `${name}`.
- `shfmt -i 2` formats every script, and `make lint` fails on unformatted code.
- Release tooling is pnpm, pinned through `packageManager` in `package.json`, running semantic-release. The release job installs it with `pnpm install --frozen-lockfile` and stops on `pnpm audit --audit-level high`.
- Dependabot updates the GitHub Actions and the release tooling, and Renovate updates the runner labels, `.ruby-version` and the Gemfile, so each update arrives once. Both look for updates three times a day, at 05:00, 13:00 and 21:00 UTC. Every bot pull request merges itself once CI passes: Renovate merges its own, and `dependabot-merge.yml` squash-merges Dependabot's at the commit CI verified, with a fixed commit body so upstream release notes never trigger a release. None is merged by hand.
- `actions/*` and `github/*` actions are referenced by version tag, such as `actions/checkout@v7.0.1`; every other action is pinned to a full commit SHA with its version in a trailing comment.
- These files are identical in every member apart from the tool's own name: `FAMILY.md`, `.editorconfig`, `.yamllint.yml`, `.github/actionlint.yaml`, `.github/dependabot.yml`, `renovate.json`, `.github/workflows/release.yml`, `.github/workflows/formula.yml`, `.github/workflows/dependabot-merge.yml`, `Gemfile`, `Gemfile.lock`, `.ruby-version`, `.simplecov`, `scripts/toolset.sh`, `scripts/coverage-gate.py`, `scripts/bashcov-run.rb` and `scripts/set-version.sh`.

## Tests

- Tests live in `test/`: `helpers.bash` for the shared helpers, `call.sh` to call one function, `run-matrix.sh`, which runs the suites under each shell named in `<TOOL>_TEST_SHELLS`, and `linux-container.sh`, which runs a command in an Ubuntu container.
- `bats` tests drive the real tools on real files, disks or media, and inject faults only through small wrappers on `PATH`.
- Golden transcripts guard the terminal output. A test runs a whole flow, replaces the values that change between runs, such as paths, sizes and rates, and compares the result with `test/golden/<flow>.<OS>.txt`. `<TOOL>_TEST_RECORD=1` rewrites them from a fresh run, on macOS and in the container; the diff is read before it is committed.
- 100 percent bashcov line coverage, gated locally and in CI. `make coverage` runs bashcov on the Mac and in the Ubuntu container and merges both before the gate, so a Linux-only branch counts locally as it does in CI. Every `case` branch runs a command, because bashcov never counts a branch that holds only `;;`.
- Tests never write the member's version as a literal; they read it from `lib/core.sh`, so a release does not break them.
- A wait loop polls from milliseconds upward, never with a fixed `sleep 1`. On a runner without `timeout`, a one-second poll per `dd` made two members ten times slower.
- Every test is three blocks, opened by the bare markers `# Arrange`, `# Act` and `# Assert`.

## Quality

- 100% shell script in POSIX `sh`, working under `sh`, `dash`, `bash` and `zsh` on both Linux and macOS, each combination tested in CI. A finding or a failure in any one of them blocks the change.
- On macOS, `bash` and `zsh` each mean two shells, and all four are tested: the system's `/bin/bash`, which is bash 3.2, and `/bin/zsh`, next to Homebrew's current builds in `$(brew --prefix)/bin`. Code that runs under bash uses nothing bash 3.2 lacks.
- ShellCheck at zero errors and zero warnings.
- No comments in source, apart from tool directives and the test markers.
- Make targets, with the same meaning in every member:

  | Target | Does |
  |:-------|:-----|
  | `make help` | Lists the targets |
  | `make fmt` | Formats every script with `shfmt -i 2` |
  | `make lint` | `shfmt -i 2 -d`, ShellCheck `-o all`, the name check and `mandoc -T lint` at zero findings |
  | `make test` | The suites under the system `sh` |
  | `make test-all` | The suites under every installed shell, both builds of bash and zsh on macOS |
  | `make test-linux` | The suites in the Ubuntu container |
  | `make coverage` | bashcov on the Mac and in the container, merged, gated at 100% |
  | `make check` | `lint` and `test` |
  | `make install` | The tool, man page and completions under `PREFIX` |

  CI installs shfmt v3.14.1 from its release binary, checked against its SHA-256.
- Conventional commits pushed straight to `main`; there are no pull requests from people. semantic-release cuts the version: a `feat` or `fix` commit publishes a release, stamps `<TOOL>_VERSION` in `lib/core.sh` through `scripts/set-version.sh` and updates `CHANGELOG.md`.
- Before every push: `make lint`, `make test-all` on macOS, `make test-linux` and `make coverage`. CI repeats them; it does not replace them.
- Any push or merge to `main` is safe at any moment, and nobody times or watches one. Push as soon as the local gates pass, never waiting for a CI or release run. The newest green push releases every commit since the last tag, and semantic-release publishes nothing from a commit `main` has already moved past.
- CI follows the owner's workflow defaults. `ci.yml` runs on every push to `main`, every pull request and at 05:23, 13:23 and 21:23 UTC, which also covers Dependabot merges, since a merge made with `GITHUB_TOKEN` starts no workflow. It has one top-level concurrency group per event and ref with `cancel-in-progress: true`, so a newer push cancels the run for an older commit while a scheduled run never cancels a push's run, which is the one that releases. The release lives in `release.yml`, started by `workflow_run` when `ci` succeeds on a push to `main`, in a group that never cancels, so no push can stop a release halfway; it asks the tap to bump through `gh workflow run formula.yml`, since a `workflow_run` workflow cannot call a reusable workflow. `step-security/harden-runner` is the first step of every job.
- macOS runners are an approved exception to the Ubuntu-only default (owner, 2026-10-29): the native and Homebrew toolsets and the macOS disk paths can only be tested there.
