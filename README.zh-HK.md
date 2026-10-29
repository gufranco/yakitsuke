<div align="center">

<h1>yakitsuke</h1>

<strong>把任何影片轉成 VCD 映像，按需要分到多張光碟，字幕在任何畫面上都保持清楚易讀。</strong>

[English](README.md) | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | 繁體中文 (香港)

[![ci](https://img.shields.io/github/actions/workflow/status/gufranco/yakitsuke/ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/gufranco/yakitsuke/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/gufranco/yakitsuke?style=flat-square&label=release)](https://github.com/gufranco/yakitsuke/releases/latest)
[![license](https://img.shields.io/github/license/gufranco/yakitsuke?style=flat-square&label=license)](LICENSE)

<p align="center">
  <a href="#quick-start"><strong>快速開始</strong></a> |
  <a href="#picture">畫質</a> |
  <a href="#subtitles">字幕</a> |
  <a href="#development">開發</a>
</p>

</div>

一條指令，163 個測試，11 個 shell 模組。除了 POSIX 系統和它調用的影片工具，執行時沒有其他依賴。`yakitsuke` 是日文「焼き付け」，意思是燒錄：把電影燒到光碟上，把字幕燒進畫面。姊妹工具 [kakikomi](https://github.com/gufranco/kakikomi) 和 [kiyome](https://github.com/gufranco/kiyome) 負責寫入和清除磁碟。

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

## 快速開始

### 先決條件

| 工具 | 用途 | 安裝 |
|:-----|:----|:--------|
| 包含 libass 和 zimg 的 `ffmpeg` | 解碼、濾鏡、字幕、16 位元色彩轉換 | `brew install ffmpeg-full`，或 `apt install ffmpeg` |
| `vcdimager` | 製作 VCD 2.0 的 BIN/CUE 映像 | `brew install vcdimager`，或 `apt install vcdimager` |
| `mjpegtools` | 較佳的 MPEG-1 編碼器 `mpeg2enc` 和 `mplex` | `brew install mjpegtools`，或 `apt install mjpegtools` |

沒有 `mjpegtools` 時會改用 ffmpeg 的編碼器，並會提示。`yakitsuke doctor` 會列出已安裝的工具。

### 安裝

```bash
brew install gufranco/tap/yakitsuke
```

或從原始碼安裝：

```bash
git clone https://github.com/gufranco/yakitsuke.git
cd yakitsuke
make install
```

`make install` 把工具、字型、man 說明頁以及 bash、zsh、fish 自動補全複製到 `~/.local`，並把 `yakitsuke` 放進 `~/.local/bin`；用 `PREFIX` 可以改變位置。Homebrew formula 安裝的是相同的檔案。

### 驗證

```console
$ yakitsuke doctor
ffmpeg             ok       /opt/homebrew/bin/ffmpeg
ffprobe            ok       /opt/homebrew/bin/ffprobe
vcdxbuild          ok       /opt/homebrew/bin/vcdxbuild
awk                ok       /usr/bin/awk, bsd 20200816
sed                ok       /usr/bin/sed, bsd
iconv              ok       /usr/bin/iconv, bsd
file               ok       /usr/bin/file
mpeg2enc           ok       /opt/homebrew/bin/mpeg2enc
mplex              ok       /opt/homebrew/bin/mplex
ffmpeg subtitles   ok       /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
ffmpeg zscale      ok       /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
```

## 用法

| 指令 | 作用 |
|:--------|:--------|
| `yakitsuke [options] <video> [subtitles]` | 把影片編碼成所需數量的光碟映像 |
| 不帶參數的 `yakitsuke` | 在終端機執行時，詢問影片和字幕檔 |
| `yakitsuke doctor` | 列出所需工具及是否已安裝 |
| `yakitsuke version`、`yakitsuke help` | 顯示版本或完整用法 |

| 選項 | 效果 |
|:-------|:-------|
| `--cd74`、`--cd80`、`--cd90`、`--disc-minutes N` | 光碟容量，預設 80 分鐘 |
| `--overlap SECONDS` | 每個光碟銜接處重複的秒數，預設 30 |
| `--scene-snap SECONDS` | 把銜接點和章節點移到最近的場景切換 |
| `--chapters MINUTES` | 每隔幾分鐘一個入口點，預設 5 |
| `--ntsc`、`--pal`、`--film` | 強制 29.97、25 或 23.976 fps |
| `--letterbox`、`--crop` | 保留完整畫面並加黑邊，或裁切填滿螢幕 |
| `--sub-color auto\|white\|yellow` | 字幕顏色 |
| `--sub-box auto\|always\|never` | 字幕背景框 |
| `--sub-track N`、`--sub-offset SECONDS` | 燒錄內嵌字幕軌，整體平移所有字幕 |
| `--preview SECONDS`、`--dry-run` | 只編碼一小段樣本，或只列印計劃 |
| `--json` | 以一個 JSON 物件輸出結果，供程式腳本使用 |
| `--resume`、`--force` | 保留已完成的光碟，或覆寫它們 |

```bash
yakitsuke movie.mkv movie.srt                  # 菲林保持菲林幀率，字幕逐行適配
yakitsuke --cd74 --pal movie.mkv               # 菲林轉 PAL：加速 4%，音調不變
yakitsuke --preview 30 movie.mkv movie.srt     # 先用 30 秒檢查效果
yakitsuke --resume movie.mkv movie.srt         # 完成被中斷的工作
```

也可以寫成 `--overlap=10`，`--` 表示選項結束。yakitsuke 遵循同系列工具共用的命令列約定，詳見 [FAMILY.md](FAMILY.md)。

<a id="picture"></a>

## 畫質

以下每個選擇都用 VMAF 量度過：按指標的設計用法放大到顯示尺寸，測試素材是 20 段標準測試片和公有領域電影。

| 環節 | 選擇 | 原因 |
|:------|:-------|:----|
| 編碼器 | 使用 TMPGEnc 量化矩陣的 `mpeg2enc` | 相對 ffmpeg 編碼器的優勢來自矩陣；TMPGEnc 曾是 VCD 的標竿編碼器 |
| 單位係數消除 | `-E -10` | VMAF +0.97、PSNR +0.27 dB，20 段全部提升 |
| 菲林 | 23.976 fps 的 NTSC Film，絕不複製到 29.97 | 同樣的幀 VMAF +7.6，沒有抖動 |
| 菲林轉 PAL | 加速 4% 並保持音調 | PAL 的慣例，取代每秒複製一幀 |
| 膠轉磁素材 | 反膠轉磁 | 還原原始菲林幀，而不是插值 |
| 縮放 | 16 位元 Lanczos、BT.601、誤差擴散抖動 | 只在最後量化一次 |
| 銳化 | 縮小後、加黑邊前做輕微銳化 | 振鈴不會延伸到黑邊邊緣 |
| 黑邊 | 先偵測並去除 | 不把碼率浪費在燒進去的邊框上 |

回報成功之前，每條碼流都會檢查是否符合 VCD 規範，每個映像都會檢查是否放得進光碟。

<a id="subtitles"></a>

## 字幕

燒進畫面的字幕觀眾無法再調整，所以每一行都按它所在的畫面來設定樣式。規則依循 BBC 字幕指引和 WCAG 對比度下限。

| 決定 | 規則 |
|:---------|:-----|
| 背景框還是描邊 | 量度每行字幕下方的畫面。畫面明亮，或細節多到干擾字形時，按 BBC 的規定逐行加 85% 不透明度的黑色背景框；其他情況用描邊加陰影，遮擋畫面較少 |
| 門檻 | 第 90 百分位亮度超過白字 4.5:1 對比度的臨界點，或邊緣密度超過 8% 時加框 |
| 顏色 | 白色，是廣播和串流的預設值。黑白電影用黃色，否則白字會融入畫面 |
| 字型 | Atkinson Hyperlegible，專為低視力人士的可讀性設計，按 SIL Open Font License 隨附 |
| 字號 | 每行佔畫面高度的 7.5%，在 BBC 容許 4:3 畫面使用的 90% 寬度以內 |
| 過長的行 | 縮小以放得下，最小 80%，所以 42 個字元的一行仍能保持一行 |
| 遮幅電影 | 放得下時文字落在黑邊裡，不壓畫面 |
| 時間 | 按每張光碟平移，銜接處不會錯位 |

帶樣式的 `.ass` 檔案保留作者的樣式。PGS、VobSub 等圖像字幕會被拒絕，並提示先做 OCR。

<a id="portability"></a>

## 可攜性

全部是 POSIX `sh`，ShellCheck `-o all` 零警告。測試在 macOS 的 `/bin/sh`、系統內置的 bash 3.2 和 zsh、Homebrew 的最新 bash 和 zsh，以及 Ubuntu 的 `dash`、`bash` 和 `zsh` 下執行。

它能在五種常用工具集上執行：Linux 上的 GNU 或 uutils coreutils，以及 macOS 內置的工具、Homebrew 中較新的版本或 Homebrew 的 uutils 工具。macOS 內置而 Homebrew 有較新版本的工具，由 bash 和 zsh 到 iconv 和 file，兩個版本都會測試。CI 在每種工具集上執行全部測試，`yakitsuke doctor` 會列出每個核心工具的類型和版本，例如 `gnu 9.7`、`uutils 0.12.0` 或 `bsd 20200816`，讓錯誤報告說明用的是哪些工具。

<a id="development"></a>

## 開發

| 指令 | 說明 |
|:--------|:------------|
| `make fmt` | 用 shfmt 格式化所有腳本 |
| `make lint` | 執行 shfmt，對所有腳本、測試和自動補全執行 ShellCheck，用 mandoc 檢查 man 說明頁 |
| `make test` | 在系統 `sh` 下執行 `bats` 測試 |
| `make test-all` | 在每種 shell 下執行同樣的測試，macOS 上包括 bash 和 zsh 的兩個版本 |
| `make test-linux` | 在 Ubuntu 容器中執行同樣的測試 |
| `make coverage` | 合併這部 Mac 與 Ubuntu 容器中的 bashcov 行覆蓋率，以及 CI 強制的 100% 門檻 |

測試用 ffmpeg、`mpeg2enc` 和 `vcdimager` 編碼真實片段，只有故障透過 `PATH` 上的小包裝程式注入。推送到 `main` 且 CI 通過後會執行 semantic-release：`feat` 或 `fix` 提交會發佈新版本，更新 [`lib/core.sh`](lib/core.sh) 裡的 `YAKITSUKE_VERSION` 和 CHANGELOG，並更新 Homebrew formula。

## 授權

[MIT](LICENSE)。隨附字型採用 [SIL Open Font License](share/fonts/OFL.txt)。
