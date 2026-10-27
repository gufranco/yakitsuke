<div align="center">

<h1>yakitsuke</h1>

<strong>把任何视频转成 VCD 镜像，按需分到多张光盘，字幕在任何画面上都保持清晰可读。</strong>

[English](README.md) | [日本語](README.ja.md) | 简体中文 | [繁體中文 (香港)](README.zh-HK.md)

[![ci](https://github.com/gufranco/yakitsuke/actions/workflows/ci.yml/badge.svg)](https://github.com/gufranco/yakitsuke/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/gufranco/yakitsuke)](https://github.com/gufranco/yakitsuke/releases)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![shell](https://img.shields.io/badge/shell-POSIX%20sh-lightgrey)](#portability)

<p align="center">
  <a href="#quick-start"><strong>快速开始</strong></a> |
  <a href="#picture">画质</a> |
  <a href="#subtitles">字幕</a> |
  <a href="#development">开发</a>
</p>

</div>

一条命令，142 个测试，11 个 shell 模块。除了 POSIX 系统和它调用的视频工具，运行时没有其他依赖。`yakitsuke` 是日语「焼き付け」，意为烧录：把电影烧到光盘上，把字幕烧进画面。姊妹工具 [kakikomi](https://github.com/gufranco/kakikomi) 和 [kiyome](https://github.com/gufranco/kiyome) 负责写入和擦除磁盘。

---

```console
$ yakitsuke --output-dir ~/Movies trailer.mp4 trailer.srt
Measuring the picture under each subtitle.

Source: trailer.mp4
        1920x1080, 2.400 display aspect, 0:00:20
        black bars stripped, active picture 1920x800 at +0+140
Target: FILM Video CD, 352x240 at 24000/1001 fps
        picture 352x134 at +0+52, letterbox
        deinterlace off, denoise off, sharpen yes
        audio track 0
        audio 0: aac, 1ch, und
        subtitles burned in: 4 lines, 4 on a box, 0 outlined
Media:  80 min, 360000 sectors, 4784.000s usable per disc
Plan:   1 disc(s), 30s overlap, mpeg2enc

Disc 1 of 1, encoding 20.020s from 0.000s
Disc 1 of 1, encoding  18%  7.4x  0m02s left
Disc 1 of 1, encoding  41%  5.5x  0m02s left
Disc 1 of 1, encoding  62%  5.0x  0m01s left
Disc 1 of 1, encoding  84%  4.7x  0m00s left
Disc 1 of 1, encoding 100%  4.2x  0m00s left
Disc 1 of 1: trailer_disc1.bin, 2187 of 360000 sectors, 0% full
Wrote 1 Video CD image(s) to ~/Movies.
```

<a id="quick-start"></a>

## 快速开始

### 前置条件

| 工具 | 用途 | 安装 |
|:-----|:----|:--------|
| 带 libass 和 zimg 的 `ffmpeg` | 解码、滤镜、字幕、16 位色彩转换 | `brew install ffmpeg-full`，或 `apt install ffmpeg` |
| `vcdimager` | 生成 VCD 2.0 的 BIN/CUE 镜像 | `brew install vcdimager`，或 `apt install vcdimager` |
| `mjpegtools` | 更好的 MPEG-1 编码器 `mpeg2enc` 和 `mplex` | `brew install mjpegtools`，或 `apt install mjpegtools` |

没有 `mjpegtools` 时会改用 ffmpeg 的编码器，并会提示。`yakitsuke doctor` 会列出已安装的工具。

### 安装

```bash
brew install gufranco/tap/yakitsuke
```

或从源码安装：

```bash
git clone https://github.com/gufranco/yakitsuke.git
cd yakitsuke
make install
```

`make install` 把工具、字体、man 手册以及 bash、zsh、fish 补全复制到 `~/.local`，并把 `yakitsuke` 放进 `~/.local/bin`；用 `PREFIX` 可以改变位置。Homebrew formula 安装的是同样的文件。

### 验证

```console
$ yakitsuke doctor
ffmpeg             ok       /opt/homebrew/bin/ffmpeg
ffprobe            ok       /opt/homebrew/bin/ffprobe
vcdxbuild          ok       /opt/homebrew/bin/vcdxbuild
awk                ok       /usr/bin/awk
sed                ok       /usr/bin/sed
iconv              ok       /usr/bin/iconv
file               ok       /usr/bin/file
mpeg2enc           ok       /opt/homebrew/bin/mpeg2enc
mplex              ok       /opt/homebrew/bin/mplex
ffmpeg subtitles   ok       /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
ffmpeg zscale      ok       /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
```

## 用法

| 命令 | 作用 |
|:--------|:--------|
| `yakitsuke [options] <video> [subtitles]` | 把视频编码成所需数量的光盘镜像 |
| 不带参数的 `yakitsuke` | 在终端中运行时，询问视频和字幕文件 |
| `yakitsuke doctor` | 列出所需工具及是否已安装 |
| `yakitsuke version`、`yakitsuke help` | 显示版本或完整用法 |

| 选项 | 效果 |
|:-------|:-------|
| `--cd74`、`--cd80`、`--cd90`、`--disc-minutes N` | 光盘容量，默认 80 分钟 |
| `--overlap SECONDS` | 每个光盘衔接处重复的秒数，默认 30 |
| `--scene-snap SECONDS` | 把衔接点和章节点移到最近的场景切换 |
| `--chapters MINUTES` | 每隔几分钟一个入口点，默认 5 |
| `--ntsc`、`--pal`、`--film` | 强制 29.97、25 或 23.976 fps |
| `--letterbox`、`--crop` | 保留完整画面并加黑边，或裁切填满屏幕 |
| `--sub-color auto\|white\|yellow` | 字幕颜色 |
| `--sub-box auto\|always\|never` | 字幕背景框 |
| `--sub-track N`、`--sub-offset SECONDS` | 烧录内嵌字幕轨，整体平移所有字幕 |
| `--preview SECONDS`、`--dry-run` | 只编码一小段样本，或只打印计划 |
| `--resume`、`--force` | 保留已完成的光盘，或覆盖它们 |

```bash
yakitsuke movie.mkv movie.srt                  # 胶片保持胶片帧率，字幕逐行适配
yakitsuke --cd74 --pal movie.mkv               # 胶片转 PAL：加速 4%，音调不变
yakitsuke --preview 30 movie.mkv movie.srt     # 先用 30 秒检查效果
yakitsuke --resume movie.mkv movie.srt         # 完成被中断的任务
```

也可以写成 `--overlap=10`，`--` 表示选项结束。yakitsuke 遵循同系列工具共用的命令行约定，详见 [FAMILY.md](FAMILY.md)。

<a id="picture"></a>

## 画质

以下每个选择都用 VMAF 测量过：按指标的设计用法放大到显示尺寸，测试素材是 20 段标准测试片和公有领域电影。

| 环节 | 选择 | 原因 |
|:------|:-------|:----|
| 编码器 | 使用 TMPGEnc 量化矩阵的 `mpeg2enc` | 相对 ffmpeg 编码器的优势来自矩阵；TMPGEnc 曾是 VCD 的标杆编码器 |
| 单位系数消除 | `-E -10` | VMAF +0.97、PSNR +0.27 dB，20 段全部提升 |
| 胶片 | 23.976 fps 的 NTSC Film，绝不复制到 29.97 | 同样的帧 VMAF +7.6，没有抖动 |
| 胶片转 PAL | 加速 4% 并保持音调 | PAL 的惯例，取代每秒复制一帧 |
| 胶转磁素材 | 反胶转磁 | 还原原始胶片帧，而不是插值 |
| 缩放 | 16 位 Lanczos、BT.601、误差扩散抖动 | 只在最后量化一次 |
| 锐化 | 缩小后、加黑边前做轻微锐化 | 振铃不会延伸到黑边边缘 |
| 黑边 | 先检测并去除 | 不把码率浪费在烧进去的边框上 |

报告成功之前，每条码流都会检查是否符合 VCD 规范，每个镜像都会检查是否放得进光盘。

<a id="subtitles"></a>

## 字幕

烧进画面的字幕观众无法再调整，所以每一行都按它所在的画面来设定样式。规则遵循 BBC 字幕规范和 WCAG 对比度下限。

| 决定 | 规则 |
|:---------|:-----|
| 背景框还是描边 | 测量每行字幕下方的画面。画面明亮，或细节多到干扰字形时，按 BBC 的规定逐行加 85% 不透明度的黑色背景框；其他情况用描边加阴影，遮挡画面更少 |
| 阈值 | 第 90 百分位亮度超过白字 4.5:1 对比度的临界点，或边缘密度超过 8% 时加框 |
| 颜色 | 白色，是广播和流媒体的默认值。黑白电影用黄色，否则白字会融进画面 |
| 字体 | Atkinson Hyperlegible，专为低视力人群的可读性设计，按 SIL Open Font License 随附 |
| 字号 | 每行占画面高度的 7.5%，在 BBC 允许 4:3 画面使用的 90% 宽度以内 |
| 过长的行 | 缩小以放下，最小 80%，所以 42 个字符的一行仍能保持一行 |
| 遮幅电影 | 放得下时文字落在黑边里，不压画面 |
| 时间 | 按每张光盘平移，衔接处不会错位 |

带样式的 `.ass` 文件保留作者的样式。PGS、VobSub 等图像字幕会被拒绝，并提示先做 OCR。

<a id="portability"></a>

## 可移植性

全部是 POSIX `sh`，ShellCheck `-o all` 零告警。测试在 macOS 的 `/bin/sh` 和 `zsh`、Ubuntu 的 `dash` 和 `zsh` 下运行。

<a id="development"></a>

## 开发

| 命令 | 说明 |
|:--------|:------------|
| `make lint` | 对所有脚本、测试和补全运行 ShellCheck，用 mandoc 检查 man 手册 |
| `make test` | 在系统 `sh` 下运行 142 个 `bats` 测试 |
| `make test-all` | 在所有已安装的 shell 下运行同样的测试 |
| `make coverage` | bashcov 行覆盖率，以及 CI 强制的 100% 门槛 |

测试用 ffmpeg、`mpeg2enc` 和 `vcdimager` 编码真实片段，只有故障通过 `PATH` 上的小包装程序注入。每次推送到 `main` 都会运行 semantic-release：`feat` 或 `fix` 提交会发布新版本，更新 [`lib/core.sh`](lib/core.sh) 里的 `YAKITSUKE_VERSION` 和 CHANGELOG，并更新 Homebrew formula。

## 许可证

[MIT](LICENSE)。随附字体采用 [SIL Open Font License](share/fonts/OFL.txt)。
