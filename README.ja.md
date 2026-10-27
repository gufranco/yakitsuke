<div align="center">

<h1>yakitsuke</h1>

<strong>あらゆる動画をビデオ CD イメージに変換し、複数のディスクに分割します。字幕はどんな映像の上でも読みやすく保たれます。</strong>

[English](README.md) | 日本語 | [简体中文](README.zh-Hans.md) | [繁體中文 (香港)](README.zh-HK.md)

[![ci](https://github.com/gufranco/yakitsuke/actions/workflows/ci.yml/badge.svg)](https://github.com/gufranco/yakitsuke/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/gufranco/yakitsuke)](https://github.com/gufranco/yakitsuke/releases)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![shell](https://img.shields.io/badge/shell-POSIX%20sh-lightgrey)](#portability)

<p align="center">
  <a href="#quick-start"><strong>クイックスタート</strong></a> |
  <a href="#picture">画質</a> |
  <a href="#subtitles">字幕</a> |
  <a href="#development">開発</a>
</p>

</div>

コマンドは一つ、テストは 135 件、シェルモジュールは 11 個。POSIX システムと、操作する映像ツール以外に実行時の依存はありません。`yakitsuke` は「焼き付け」です。映画を CD に焼き、字幕を映像に焼き付けます。姉妹ツールの [kakikomi](https://github.com/gufranco/kakikomi) と [kiyome](https://github.com/gufranco/kiyome) はディスクの書き込みと消去を行います。

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

## クイックスタート

### 必要なもの

| ツール | 用途 | インストール |
|:-----|:----|:--------|
| libass と zimg を含む `ffmpeg` | デコード、フィルタ、字幕、16 ビット色変換 | `brew install ffmpeg-full`、または `apt install ffmpeg` |
| `vcdimager` | VCD 2.0 の BIN/CUE イメージを作成 | `brew install vcdimager`、または `apt install vcdimager` |
| `mjpegtools` | より高画質な MPEG-1 エンコーダの `mpeg2enc` と `mplex` | `brew install mjpegtools`、または `apt install mjpegtools` |

`mjpegtools` がない場合は ffmpeg のエンコーダに切り替え、その旨を表示します。`yakitsuke doctor` でインストール状況を確認できます。

### インストール

```bash
brew install gufranco/tap/yakitsuke
```

ソースからの場合:

```bash
git clone https://github.com/gufranco/yakitsuke.git
cd yakitsuke
make install
```

`make install` はツールを `~/.local` に配置し、`yakitsuke` を `~/.local/bin` に置きます。場所は `PREFIX` で変更できます。

### 確認

```console
$ yakitsuke --version
yakitsuke 1.0.0
```

## 使い方

| コマンド | 目的 |
|:--------|:--------|
| `yakitsuke <video> [subtitles]` | 必要な枚数のディスクイメージに動画をエンコード |
| 引数なしの `yakitsuke` | 端末で実行すると、動画と字幕ファイルを尋ねる |
| `yakitsuke doctor` | 必要なツールとインストール状況を一覧表示 |
| `yakitsuke version`、`yakitsuke help` | バージョンまたは使い方の全文を表示 |

| オプション | 効果 |
|:-------|:-------|
| `--cd74`、`--cd80`、`--cd90`、`--disc-minutes N` | メディアの容量。既定は 80 分 |
| `--overlap SECONDS` | ディスクの継ぎ目で重複させる秒数。既定は 30 |
| `--scene-snap SECONDS` | 継ぎ目とチャプターを最も近いシーンチェンジへ移動 |
| `--chapters MINUTES` | 数分ごとのエントリーポイント。既定は 5 |
| `--ntsc`、`--pal`、`--film` | 29.97、25、23.976 fps を強制 |
| `--letterbox`、`--crop` | 黒帯付きで全体を残すか、画面いっぱいに切り取るか |
| `--sub-color auto\|white\|yellow` | 字幕の色 |
| `--sub-box auto\|always\|never` | 字幕の背景ボックス |
| `--sub-track N`、`--sub-offset SECONDS` | 内蔵トラックの焼き付け、全行のタイミング移動 |
| `--preview SECONDS`、`--dry-run` | 短いサンプルだけをエンコード、または計画だけを表示 |
| `--resume`、`--force` | 完成済みのディスクを残すか、上書きするか |

```bash
yakitsuke movie.mkv movie.srt                  # フィルムはフィルムのまま、字幕は行ごとに調整
yakitsuke --cd74 --pal movie.mkv               # フィルムから PAL: 4% 速め、音程は維持
yakitsuke --preview 30 movie.mkv movie.srt     # まず 30 秒で見た目を確認
yakitsuke --resume movie.mkv movie.srt         # 中断した処理を完了
```

<a id="picture"></a>

## 画質

以下の選択はすべて、標準テストクリップ 20 本とパブリックドメインの映画で、表示サイズに拡大した VMAF で測定しました。

| 段階 | 選択 | 理由 |
|:------|:-------|:----|
| エンコーダ | TMPGEnc の量子化マトリクスを使う `mpeg2enc` | ffmpeg のエンコーダとの差はマトリクスが生む。TMPGEnc は VCD の基準となったエンコーダ |
| 単位係数の除去 | `-E -10` | VMAF +0.97、PSNR +0.27 dB、20 本すべてで向上 |
| フィルム | 23.976 fps の NTSC Film。29.97 への複製はしない | 同じフレームで VMAF +7.6、ジャダーなし |
| フィルムから PAL | 音程を保った 4% の速度アップ | 毎秒フレームを複製する代わりの、PAL の慣習 |
| テレシネ素材 | 逆テレシネ | 補間ではなく元のフィルムフレームを復元 |
| スケーリング | 16 ビットの Lanczos、BT.601、誤差拡散ディザ | 再量子化は最後の一回だけ |
| シャープ化 | 縮小後、黒帯を付ける前に弱いアンシャープ | リンギングが黒帯の境に届かない |
| 黒帯 | 最初に検出して除去 | 焼き込まれた枠にビットを使わない |

成功を報告する前に、すべてのストリームはビデオ CD 規格への適合を、すべてのイメージはメディア容量を確認します。

<a id="subtitles"></a>

## 字幕

焼き付けた字幕は視聴者が変更できないため、各行を下の映像に合わせてスタイル付けします。規則は BBC の字幕ガイドラインと WCAG のコントラスト基準に従います。

| 判断 | 規則 |
|:---------|:-----|
| ボックスか縁取りか | 各行の下の映像を測定します。明るい映像や、文字と競うほど細かい映像では、BBC の指定どおり行ごとに不透明度 85% の黒いボックスを付けます。それ以外は映像を隠しにくい縁取りと影を使います |
| しきい値 | 90 パーセンタイル輝度が白文字の 4.5:1 コントラストを超えるとき、またはエッジ密度が 8% を超えるときにボックス |
| 色 | 放送と配信の標準である白。白黒映画では白文字が映像に溶け込むため黄色 |
| フォント | 弱視の人の読みやすさのために設計された Atkinson Hyperlegible。SIL Open Font License で同梱 |
| サイズ | 1 行あたり映像の高さの 7.5%。BBC が 4:3 に認める幅 90% の範囲内 |
| 長い行 | 収まるよう縮小。80% 未満にはしないので、42 文字の行も 1 行に収まる |
| レターボックスの映画 | 収まる場合は文字を黒帯に置き、映像にかからない |
| タイミング | ディスクごとに移動するので、継ぎ目で行がずれない |

スタイル付きの `.ass` ファイルは作者のスタイルを保ちます。PGS や VobSub などの画像字幕は、まず OCR にかけるよう案内して拒否します。

<a id="portability"></a>

## 移植性

すべて POSIX `sh` で、ShellCheck `-o all` の指摘はゼロです。テストは macOS の `/bin/sh` と `zsh`、Ubuntu の `dash` と `zsh` で実行します。

<a id="development"></a>

## 開発

| コマンド | 説明 |
|:--------|:------------|
| `make lint` | すべてのスクリプトとテストに ShellCheck |
| `make test` | システムの `sh` で 135 件の `bats` テスト |
| `make test-all` | インストール済みのすべてのシェルで同じテスト |
| `make coverage` | bashcov の行カバレッジと、CI が強制する 100% のゲート |

テストは ffmpeg、`mpeg2enc`、`vcdimager` で実際のクリップをエンコードします。故障だけを `PATH` 上の小さなラッパーで注入します。`main` への push ごとに semantic-release が動き、`feat` か `fix` のコミットでリリースを公開し、[`lib/core.sh`](lib/core.sh) の `YAKITSUKE_VERSION` と CHANGELOG を更新し、Homebrew の formula を更新します。

## ライセンス

[MIT](LICENSE)。同梱フォントは [SIL Open Font License](share/fonts/OFL.txt) です。
