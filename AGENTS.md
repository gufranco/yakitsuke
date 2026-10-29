# yakitsuke

Guidance for anyone, human or agent, changing yakitsuke. What yakitsuke is and how to use it lives in [README.md](README.md).

[FAMILY.md](FAMILY.md) holds everything yakitsuke shares with the rest of the kodougu family, and it is the same in every member. This file holds only what is exclusive to yakitsuke, under the same headings as the agent guide of every member. Read both before changing anything; a rule that would serve the other members goes into `FAMILY.md` instead of here.

## Layout

| Path | Holds |
|:-----|:------|
| [`bin/yakitsuke`](bin/yakitsuke) | The entry point: dispatch, prompts and cleanup |
| [`lib/`](lib) | The modules, plus two awk programs. [`lib/state.sh`](lib/state.sh) declares every global |
| [`share/fonts/`](share/fonts) | Atkinson Hyperlegible, bundled under the SIL Open Font License, and its advance widths |
| [`man/yakitsuke.1`](man/yakitsuke.1) | The man page |
| [`completions/`](completions) | bash, zsh and fish completions |
| [`test/`](test) | The `bats` suite, its helpers and the shell matrix runner |
| [`scripts/`](scripts) | Coverage, the coverage gate, the name check, the toolset helper and the release version stamp |

## Names

- Globals carry `YK_`; function-scoped variables carry a per-function `yk_` prefix.
- Settings come from `YAKITSUKE_<NAME>`; test switches are `YAKITSUKE_TERMINAL` and `YAKITSUKE_TEST_SHELLS`.
- Output goes through `yk_info`, `yk_say`, `yk_error` and `yk_warning`.

## Behaviour

- yakitsuke has one job, so a bare `yakitsuke` on a terminal asks for the video and the subtitle file directly.
- Its options are grouped by subject on the help page, because there are many of them.

## Domain rules

- Every encoder setting was chosen by measurement. A change to the picture chain or the subtitle style carries a VMAF or visual measurement that beats the current one.
- Tests encode real clips that ffmpeg generates, through real `mpeg2enc` and `vcdxbuild`.

## Release

- `YAKITSUKE_VERSION` lives in [`lib/core.sh`](lib/core.sh).
- The tap's `Formula/yakitsuke.rb` installs the bundled fonts next to the modules, and depends on `ffmpeg-full`, `mjpegtools` and `vcdimager`.

## Gaps against FAMILY.md

As of 2026-10-29, closed in the change that removes each line:

- No `make test-linux`, `test/linux-container.sh` or merged local coverage.
- No golden transcripts.
- No `--json` for the images a run produced.
- `vcdxbuild` writes each disc's `.bin` and `.cue` straight to their final paths, so an interrupted run can leave half an image.
