# The family standard

fusho, kakikomi, kiyome and yakitsuke are one family of command-line tools. They look, read and behave alike, so a person who knows one already knows how to drive the others. This file is the contract they share.

| Member | What it does | Repository |
|:-------|:-------------|:-----------|
| fusho | Sends an encrypted message through any chat, using the recipient's published SSH keys | [gufranco/fusho](https://github.com/gufranco/fusho) |
| kakikomi | Writes a disk image to removable media, verified chunk by chunk, never mounted | [gufranco/kakikomi](https://github.com/gufranco/kakikomi) |
| kiyome | Overwrites a disk with five verified patterns and names any failing bit line | [gufranco/kiyome](https://github.com/gufranco/kiyome) |
| yakitsuke | Turns any video into Video CD images, split across discs, with readable subtitles | [gufranco/yakitsuke](https://github.com/gufranco/yakitsuke) |

## How a repository joins

Copy this file in unchanged, follow it, and add the repository to the table above in every member in the same task. Everything above the closing line is shared and must match across the members; with the members checked out side by side, this shows any drift:

```bash
for member in fusho kakikomi kiyome yakitsuke; do
  diff <(sed '/^---$/q' FAMILY.md) <(sed '/^---$/q' "../${member}/FAMILY.md")
done
```

A rule that needs changing is changed in every member in the same task. The Homebrew tap that ships the members, [gufranco/homebrew-tap](https://github.com/gufranco/homebrew-tap), is not a member: it also carries tools and apps outside the family.

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
- kakikomi and kiyome also read their original environment variables, such as `PASSES=3`, as the same settings. An option on the command line wins over the environment.
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
| macOS, BSD | The tools macOS ships |
| macOS, GNU | Homebrew's coreutils, findutils, gnu-sed, gawk, grep and diffutils, first on `PATH` |
| macOS, uutils | Homebrew's uutils-coreutils, uutils-diffutils and uutils-findutils, first on `PATH` |

- A script uses only options all five accept. Where they differ, the code handles each one and a test covers it.
- `scripts/toolset.sh gnu` or `scripts/toolset.sh uutils` prints the directories that put a toolset first on `PATH`; CI uses it, and so can a person reproducing a report.

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

## Quality

- POSIX `sh`, tested under `sh`, `dash`, `bash` and `zsh`.
- ShellCheck at zero findings.
- `bats` tests that drive the real tools, injecting faults only through small wrappers on `PATH`.
- 100 percent bashcov line coverage, gated in CI.
- No comments in source, apart from tool directives and the `Arrange`, `Act`, `Assert` markers in tests.
- Make targets: `help`, `lint`, `test`, `coverage`, `check`, `install`.
- Conventional commits pushed to `main`; semantic-release cuts the version.

---

*Everything above this line is identical in every member. A member may add sections below it about its own state, and nothing may be added above it that the others do not also get.*

## The state of this repository

yakitsuke has one job, so a bare `yakitsuke` on a terminal asks for the video and the subtitle file directly. Its options are grouped by subject on the help page because there are many of them.

Gaps against the family standard (as of 2026-10-27): none.
