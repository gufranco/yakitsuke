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
| [`scripts/`](scripts) | Coverage, the coverage gate, the Linux coverage run and the name check, which `make` runs |
| [`.github/scripts/`](.github/scripts) | The toolset helper and the release version stamp, which only CI and the release run |

## Names

- Globals carry `YK_`; function-scoped variables carry a per-function `yk_` prefix.
- Settings come from `YAKITSUKE_<NAME>`, such as `YAKITSUKE_FFMPEG` and `YAKITSUKE_THEME`; test switches are `YAKITSUKE_TEST_SHELLS`, `YAKITSUKE_TEST_RECORD`, `YAKITSUKE_TEST_IMAGE` and `YAKITSUKE_TEST_GUM`.
- Output goes through `yk_info`, `yk_say`, `yk_error` and `yk_warning`, which hand over to the `yk_ui_` helpers in [`lib/ui.sh`](lib/ui.sh) where gum draws.

## Behaviour

- yakitsuke has one job, so a bare `yakitsuke` on a terminal asks for the video and the subtitle file directly.
- Its options are grouped by subject on the help page, because there are many of them.
- Where gum draws, a run that encodes asks to confirm after the summary, and the encode progress is a bar; a dry run and a run without a terminal never ask.
- `--json` reports the source, the output folder, the media capacity in sectors, and each disc's image, cue sheet, size and whether `--resume` kept it; with `--dry-run`, each disc's planned start and length.

## Domain rules

- Every encoder setting was chosen by measurement. A change to the picture chain or the subtitle style carries a VMAF or visual measurement that beats the current one.
- Tests encode real clips that ffmpeg generates, through real `mpeg2enc` and `vcdxbuild`.
- Homebrew's plain `ffmpeg` has neither libass nor libsoxr. Without libsoxr, yakitsuke resamples with ffmpeg's own engine; without libass it refuses to burn subtitles and names `ffmpeg-full`. Tests that burn subtitles carry `# bats test_tags=libass`, and the macOS leg that installs plain `ffmpeg` runs the suite with `--filter-tags '!libass'`.
- Each disc's image is built in a hidden staging folder inside the output folder, then moved into place, so `--resume` never finds half an image. The cue sheet names its image without a folder, so the pair can move together.
- `yk_format_params` in [`lib/geometry.sh`](lib/geometry.sh) sets the raster, line width, codec, image class, GOP and frame rate of Super Video CD, and turns `--encoder auto` into ffmpeg for everything but NTSC film, as the VMAF measurements chose; the rest of the picture chain reads those variables.
- A Super Video CD line carries the 704 active samples of BT.601 in 470 of its 480 samples, centred, as a Video CD line carries them in 352. A circle test pattern measured after a player's 480 to 720 upscale decides any change to that mapping.
- Super Video CD keeps the 2516 kbit/s video peak and the 224 KiB buffer of IEC 62107; only the average moves, between `YK_SVCD_REF_KBPS` and `YK_SVCD_MAX_KBPS`, to fill each disc.
- Standard SVCD in `mpeg2enc`, `-f 4`, writes no repeat-field flags, so 23.976 fps film is coded as user SVCD, `-f 5 -p`. ffmpeg's encoder has no soft pulldown and duplicates to 29.97 instead.
- Super Video CD subtitles stay burned in, because the only encoder for its OGT subtitle stream is a proof of concept.

## Release

- `YAKITSUKE_VERSION` lives in [`lib/core.sh`](lib/core.sh).
- The tap's `Formula/yakitsuke.rb` installs the bundled fonts next to the modules, and depends on `ffmpeg-full`, `gum`, `mjpegtools` and `vcdimager`.

## Gaps against FAMILY.md

None (as of 2026-10-30).
