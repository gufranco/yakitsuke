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
| [`test/`](test) | The `bats` suite, its helpers, the golden transcripts, the shell matrix runner and the Linux container script |
| [`scripts/`](scripts) | Coverage, the coverage gate, the Linux coverage run, the name check, the toolset helper and the release version stamp |

## Names

- Globals carry `YK_`; function-scoped variables carry a per-function `yk_` prefix.
- Settings come from `YAKITSUKE_<NAME>`, such as `YAKITSUKE_FFMPEG`; test switches are `YAKITSUKE_TERMINAL`, `YAKITSUKE_TEST_SHELLS`, `YAKITSUKE_TEST_RECORD` and `YAKITSUKE_TEST_IMAGE`.
- Output goes through `yk_info`, `yk_say`, `yk_error` and `yk_warning`.

## Behaviour

- yakitsuke has one job, so a bare `yakitsuke` on a terminal asks for the video and the subtitle file directly.
- Its options are grouped by subject on the help page, because there are many of them.
- `--json` reports the source, the output folder, the media capacity in sectors, and each disc's image, cue sheet, size and whether `--resume` kept it; with `--dry-run`, each disc's planned start and length.

## Domain rules

- Every encoder setting was chosen by measurement. A change to the picture chain or the subtitle style carries a VMAF or visual measurement that beats the current one.
- Tests encode real clips that ffmpeg generates, through real `mpeg2enc` and `vcdxbuild`.
- Each disc's image is built in a hidden staging folder inside the output folder, then moved into place, so `--resume` never finds half an image. The cue sheet names its image without a folder, so the pair can move together.

## Release

- `YAKITSUKE_VERSION` lives in [`lib/core.sh`](lib/core.sh).
- The tap's `Formula/yakitsuke.rb` installs the bundled fonts next to the modules, and depends on `ffmpeg-full`, `mjpegtools` and `vcdimager`.

## Gaps against FAMILY.md

As of 2026-10-29, closed in the change that removes each line:

- No Linux BusyBox or Linux Homebrew leg in CI or `scripts/toolset.sh`.
- The member's own dependencies are not yet tested in every build the seven toolsets offer.
