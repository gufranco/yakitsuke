# yakitsuke

Guidance for anyone, human or agent, changing this repository. What yakitsuke is and how to use it lives in [README.md](README.md); this file covers how the code is built, tested and shipped.

## Family

yakitsuke is one of the tools that share a single command-line contract: [FAMILY.md](FAMILY.md), which lists every member. Help page, options, prompts, output, diagnostics and `doctor` follow it. A change to the contract goes into `FAMILY.md` in every member's repository at once.

## Layout

| Path | Holds |
|:-----|:------|
| [`bin/yakitsuke`](bin/yakitsuke) | The entry point: dispatch, prompts and cleanup |
| [`lib/`](lib) | The modules it sources, plus two awk programs. [`lib/state.sh`](lib/state.sh) declares every global |
| [`share/fonts/`](share/fonts) | Atkinson Hyperlegible, bundled under the SIL Open Font License, and its advance widths |
| [`man/yakitsuke.1`](man/yakitsuke.1) | The man page |
| [`completions/`](completions) | bash, zsh and fish completions |
| [`test/`](test) | The `bats` suite, its helpers and the shell matrix runner |
| [`scripts/`](scripts) | Coverage, the coverage gate, the name check and the release version stamp |

## Commands

| Command | Does |
|:--------|:-----|
| `make lint` | ShellCheck `-o all` on scripts, tests and the bash completion, mandoc on the man page, and the duplicate-function check |
| `make test` | Every `bats` test under the system `sh` |
| `make test-all` | The same tests under `sh`, `dash`, `bash`, `bash --posix` and `zsh`; on macOS, under both the system's bash and zsh and Homebrew's |
| `make coverage` | bashcov line coverage, gated at 100% |
| `make install` | Installs the tool, man page and completions under `~/.local` |

## Hard rules

- 100% shell script, with zero ShellCheck errors and zero warnings, and it works under `sh`, `bash` and `zsh` on both Linux and macOS (owner's rule, 2026-10-25). On macOS, every tool the system ships that Homebrew also builds in a newer version, bash and zsh included, is tested in both builds (owner's rule, 2026-10-27). CI proves every combination on each push; a finding or a failure in any one of them blocks the change.
- It runs on all five toolsets in [FAMILY.md](FAMILY.md): Linux with GNU coreutils, Linux with uutils coreutils, macOS with the tools it ships, macOS with Homebrew's newer builds of them, and macOS with Homebrew's uutils tools. Never use an option one of them lacks; where they differ, handle each one in code and cover it with a test. A change that passes on one toolset only is not done.
- CI runs the suite on every toolset through [`scripts/toolset.sh`](scripts/toolset.sh). To reproduce a report, put the reporter's toolset first: `export PATH="$(sh scripts/toolset.sh gnu | paste -sd: -):$PATH"`.
- `doctor` names the flavor and version of every core tool it lists, such as `gnu 9.7`, `uutils 0.12.0` or `bsd 20200816`. A new core dependency gets a `doctor` row with its flavor in the same change.
- [CLAUDE.md](CLAUDE.md) holds only `@AGENTS.md`. Rules for this repository live here, never there.
- POSIX `sh` only. Every function-scoped variable carries the function's `yk_` prefix, because `sh` has no `local`.
- Every environment variable yakitsuke reads is named `YAKITSUKE_<NAME>`, test switches included (owner's rule, 2026-10-28). Globals carry `YK_`, and [`bin/yakitsuke`](bin/yakitsuke) clears every inherited `YK_` variable before it sources the modules, so the environment never sets one. [`scripts/check-names.sh`](scripts/check-names.sh) fails lint on any other name.
- Every line yakitsuke prints to a terminal fits in 80 columns (owner's rule, 2026-10-28). Text with a path or another value of any length goes through `yk_info`, `yk_say`, `yk_error` or `yk_warning`, which wrap between words when stdout is a terminal and keep a message on one line in a pipe; `YAKITSUKE_TERMINAL=1` makes a test behave as a terminal. [`test/width.bats`](test/width.bats) checks help and version. `doctor` is exempt and keeps one row per tool at any width.
- No comments in source. Tool directives and the `Arrange`, `Act`, `Assert` markers in tests are the only exceptions.
- Tests encode real clips that ffmpeg generates, through real `mpeg2enc` and `vcdxbuild`. Faults come only from small wrappers placed on `PATH`.
- Every encoder setting was chosen by measurement. A change to the picture chain or the subtitle style needs a VMAF or visual measurement that beats the current one, recorded in the commit body.
- A new option goes into the help page, the man page and all three completions in the same commit; a test fails otherwise.
- Conventional commits, pushed straight to `main`. No pull requests.

## Release and Homebrew

- Once CI passes on a push to `main`, [`.github/workflows/release.yml`](.github/workflows/release.yml) runs semantic-release. A `feat` or `fix` commit publishes a release, stamps `YAKITSUKE_VERSION` in [`lib/core.sh`](lib/core.sh) and updates the CHANGELOG.
- The Homebrew formula is not in this repository. It lives in [gufranco/homebrew-tap](https://github.com/gufranco/homebrew-tap) as `Formula/yakitsuke.rb`, next to the formulas for the rest of the family and for other projects.
- After a release, [`.github/workflows/formula.yml`](.github/workflows/formula.yml) sends a `formula-bump` dispatch to the tap with the new tag. The tap rewrites the formula's `url` and `sha256` itself, so neither is edited by hand.
- The dispatch authenticates as a GitHub App through the `TAP_APP_ID` and `TAP_APP_PRIVATE_KEY` secrets of this repository.
- The formula's `install` block decides which files reach users. A new file that must be installed, or a new dependency, needs a matching change to `Formula/yakitsuke.rb` in the tap.
- On Linux, the dotfiles install yakitsuke from a clone with `make install`.
