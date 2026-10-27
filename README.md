<div align="center">

<h1>yakitsuke</h1>

<strong>Turn any video into Video CD images, split across discs, with subtitles that stay readable on any picture.</strong>

English | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [繁體中文 (香港)](README.zh-HK.md)

[![ci](https://github.com/gufranco/yakitsuke/actions/workflows/ci.yml/badge.svg)](https://github.com/gufranco/yakitsuke/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/gufranco/yakitsuke)](https://github.com/gufranco/yakitsuke/releases)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![shell](https://img.shields.io/badge/shell-POSIX%20sh-lightgrey)](#portability)

<p align="center">
  <a href="#quick-start"><strong>Quick start</strong></a> |
  <a href="#picture">Picture</a> |
  <a href="#subtitles">Subtitles</a> |
  <a href="#development">Development</a>
</p>

</div>

One command, 135 tests, 11 shell modules, and no runtime beyond a POSIX system and the video tools it drives. `yakitsuke` is 焼き付け, Japanese for burning in: it burns a film onto CD and burns the subtitles into the picture. Its companions [kakikomi](https://github.com/gufranco/kakikomi) and [kiyome](https://github.com/gufranco/kiyome) write and wipe disks.

---

```console
$ yakitsuke trailer.mp4 trailer.srt
  measuring the picture under each subtitle
Source     trailer.mp4
  1920x1080, 2.347 display aspect, 0:00:40
  black bars stripped, active picture 1920x818 at +0+130
Target     FILM Video CD, 352x240 at 24000/1001 fps
  picture 352x136 at +0+52, letterbox
  deinterlace off, denoise off, sharpen yes
  audio track 0
  audio 0: aac, 1ch, und
  subtitles burned in: 13 lines, 8 on a box, 5 outlined
Media      80 min, 360000 sectors, 4784.000s usable per disc
Plan       1 disc(s), 30s overlap, mpeg2enc
Disc 1 of 1: encoding 40.000s from 0.000s
  image 3690 of 360000 sectors, 1% full
Disc 1 of 1: trailer_disc1.bin
Wrote 1 Video CD image(s) to ~/Movies
```

<a id="quick-start"></a>

## Quick start

### Prerequisites

| Tool | Why | Install |
|:-----|:----|:--------|
| `ffmpeg` with libass and zimg | Decoding, filtering, subtitles, 16-bit colour conversion | `brew install ffmpeg-full`, or `apt install ffmpeg` |
| `vcdimager` | Writes the VCD 2.0 BIN/CUE image | `brew install vcdimager`, or `apt install vcdimager` |
| `mjpegtools` | `mpeg2enc` and `mplex`, the better MPEG-1 encoder | `brew install mjpegtools`, or `apt install mjpegtools` |

Without `mjpegtools` the run falls back to ffmpeg's encoder and says so. `yakitsuke doctor` lists what is installed.

### Install

```bash
brew install gufranco/tap/yakitsuke
```

Or from source:

```bash
git clone https://github.com/gufranco/yakitsuke.git
cd yakitsuke
make install
```

`make install` copies the tool under `~/.local` and puts `yakitsuke` in `~/.local/bin`; set `PREFIX` to change that.

### Verify

```console
$ yakitsuke --version
yakitsuke 1.0.0
```

## Usage

| Command | Purpose |
|:--------|:--------|
| `yakitsuke <video> [subtitles]` | Encode the video into as many disc images as it needs |
| `yakitsuke` with no arguments | Ask for the video and the subtitle file, when run in a terminal |
| `yakitsuke doctor` | List the tools yakitsuke needs and whether they are installed |
| `yakitsuke version`, `yakitsuke help` | Print the version or the full usage page |

| Option | Effect |
|:-------|:-------|
| `--cd74`, `--cd80`, `--cd90`, `--disc-minutes N` | Media size, 80 minutes by default |
| `--overlap SECONDS` | Footage repeated at each disc seam, 30 by default |
| `--scene-snap SECONDS` | Move each seam and chapter mark onto the nearest scene change |
| `--chapters MINUTES` | An entry point every few minutes, 5 by default |
| `--ntsc`, `--pal`, `--film` | Force 29.97, 25 or 23.976 fps |
| `--letterbox`, `--crop` | Keep the whole frame with bars, or fill the screen |
| `--sub-color auto\|white\|yellow` | Subtitle colour |
| `--sub-box auto\|always\|never` | Background box behind subtitles |
| `--sub-track N`, `--sub-offset SECONDS` | Burn an embedded track, shift every line |
| `--preview SECONDS`, `--dry-run` | Encode a short sample, or only print the plan |
| `--resume`, `--force` | Keep finished discs, or overwrite them |

```bash
yakitsuke movie.mkv movie.srt                  # film stays film, subtitles adapt per line
yakitsuke --cd74 --pal movie.mkv               # PAL from film: sped up 4%, pitch kept
yakitsuke --preview 30 movie.mkv movie.srt     # check the look on 30 seconds first
yakitsuke --resume movie.mkv movie.srt         # finish an interrupted run
```

<a id="picture"></a>

## Picture

Every choice below was measured with VMAF, scaled to display size the way the metric is meant to be used, on 20 standard test clips and on public domain films.

| Stage | Choice | Why |
|:------|:-------|:----|
| Encoder | `mpeg2enc` with the TMPGEnc matrices | The matrices carry the gain over ffmpeg's encoder; TMPGEnc was the reference VCD encoder |
| Unit coefficient elimination | `-E -10` | +0.97 VMAF, +0.27 dB PSNR, better on all 20 clips |
| Film | 23.976 fps NTSC Film, never duplicated to 29.97 | +7.6 VMAF on the same frames, no judder |
| Film to PAL | 4% speed-up with pitch kept | The PAL convention, instead of a duplicated frame every second |
| Telecined sources | Inverse telecine | Recovers the original film frames instead of interpolating them |
| Scaling | Lanczos at 16 bits, BT.601, error-diffusion dither | One requantisation, at the end |
| Sharpening | A mild unsharp after the downscale, before any bars | Ringing never reaches the bar edge |
| Black bars | Detected and stripped first | No bits spent on baked-in borders |

Every stream is checked for Video CD conformance and every image against the media size before the run reports success.

<a id="subtitles"></a>

## Subtitles

Burned-in subtitles cannot be restyled by the viewer, so each line is styled for the picture it sits on. The rules follow the BBC subtitle guidelines and the WCAG contrast floor.

| Decision | Rule |
|:---------|:-----|
| Box or outline | Each line is measured against the picture under it. Where the picture is bright, or busy enough to fight the letters, the line gets a black box at 85% opacity, one per line as the BBC specifies. Elsewhere it gets an outline and shadow, which hide less of the picture |
| Threshold | A box when the 90th percentile luma passes the 4.5:1 contrast point for white text, or when the edge density passes 8% |
| Colour | White, the broadcast and streaming default. Yellow for black and white films, where white text would merge with the picture |
| Font | Atkinson Hyperlegible, designed for low-vision legibility and bundled under the SIL Open Font License |
| Size | 7.5% of the picture height per line, inside the 90% width the BBC allows for 4:3 |
| Long lines | Scaled down to fit, never below 80%, so a 42-character line stays on one row |
| Letterboxed films | The text drops into the black bar where it fits, clear of the picture |
| Timing | Shifted per disc, so a seam never desynchronises a line |

Styled `.ass` files keep their author's styling. Picture-based tracks such as PGS or VobSub are refused with the way out: run them through OCR first.

<a id="portability"></a>

## Portability

Everything is POSIX `sh` with ShellCheck `-o all` at zero findings. The suites run on macOS under `/bin/sh` and `zsh`, and on Ubuntu under `dash` and `zsh`.

<a id="development"></a>

## Development

| Command | Description |
|:--------|:------------|
| `make lint` | ShellCheck on every script and test |
| `make test` | The 135 `bats` tests under the system `sh` |
| `make test-all` | The same tests under every installed shell |
| `make coverage` | bashcov line coverage, with the 100% gate CI enforces |

The tests encode real clips with ffmpeg, `mpeg2enc` and `vcdimager`; only failures are injected, through small wrappers on `PATH`. Every push to `main` runs semantic-release: a `feat` or `fix` commit publishes a release, updates `YAKITSUKE_VERSION` in [`lib/core.sh`](lib/core.sh) and the CHANGELOG, and bumps the Homebrew formula.

## License

[MIT](LICENSE). The bundled font is under the [SIL Open Font License](share/fonts/OFL.txt).
