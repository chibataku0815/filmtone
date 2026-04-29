# Filmtone HDR Fixture & FFmpeg Capability Inventory

Last updated: 2026-04-24
Authoring context: Claude Code desktop session
Primary repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
Scope: `apps/desktop-film-lab-batch` HDR preparation policy readiness.

## 1. Purpose

P0-C の pure helper と sidecar/log visibility は landed。次は pixel を変える前段として、

- ローカル ffmpeg が HDR→SDR 変換 filter を持つかの capability 可視化
- PQ / HLG / SDR BT.709 regression fixtures の所在・不足の明確化

の 2 点だけを inventory として記録する。本ドキュメントは fixture 追加・pipeline 変更のための前提を整理するもので、pixel-changing な実装は一切含めない。

## 2. FFmpeg Capability — 現状 (2026-04-24)

### 2.1 計測環境

- binary: `/opt/homebrew/bin/ffmpeg`
- version: `ffmpeg version 8.0.1` (Homebrew 本家の bottle 由来)
- 計測: `ffmpeg -hide_banner -filters` から filter 名抽出
- 参照コード: `apps/desktop-film-lab-batch/electron/ffmpeg-capability-probe.ts`

### 2.2 HDR 関連 filter の有無

| filter | 状態 | HDR 変換に必要な役割 |
|---|---|---|
| `tonemap` | ✅ available | linear-light GBRAPF32 上で hable/mobius 等の tone curve 適用 |
| `colorspace` | ✅ available | matrix / primaries 変換専用。**transfer 変換はしない** |
| `zscale` | ❌ **missing** (libzimg 未リンク) | PQ `smpte2084` 逆 EOTF・HLG OOTF の正攻法 |
| `libplacebo` | ❌ **missing** | BT.2390 tone map・GPU 経路の代替 |

### 2.3 影響

- **PQ (`smpte2084`)**: stock `tonemap` は linear-light 前提のため、PQ source を直接流せない。上流で `zscale=transfer=linear:npl=100` 相当が必要だが未搭載。`colorspace` は transfer を扱わないので代替不可。→ **現状 ffmpeg では PQ→SDR 正確 pipeline を書けない**。
- **HLG (`arib-std-b67`)**: OOTF / peak-nit normalization を行う手段がなく、double-tone-map risk。
- **wide-gamut-unknown**: これは policy 側で `defer-unknown` のまま。

### 2.4 Runtime guard (landed 2026-04-24)

`deriveDesktopHdrPreparationPolicy(sourceVideoMetadata, capabilities)` は capability data を受け取り、

- `hdr-pq` / `hdr-hlg` + `!hasZscale && !hasLibplacebo` → `strategy: "defer-unknown"` / `reason: "ffmpeg-missing-hdr-filters"` / `warning` に欠落 filter を列挙。
- それ以外は従来挙動。

つまり pixel は一切変えないまま「HDR source を受けた時に何故変換しないか」が sidecar / export log に残る。

## 3. FFmpeg ビルド強化オプション

実 pipeline を書く前に、どのビルドに差し替えるかを決める必要がある。

| 候補 | 入手性 | 利点 | 課題 |
|---|---|---|---|
| `brew tap homebrew-ffmpeg/ffmpeg` + `brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-zimg --with-libplacebo` | 中 | 開発機で最短、zscale + libplacebo 両対応 | user 環境に依存。Filmtone Desktop の end user は別。packaged app は bundled ffmpeg が別途必要 |
| 公式 static build (`johnvansickle`, `BtbN/FFmpeg-Builds`) | 高 | zscale/libplacebo 同梱、Apple Silicon もあり | 再配布ライセンス注意。ユーザーが手動 install |
| 自前 compile (`--enable-libzimg --enable-libplacebo`) | 低 | フル制御 | メンテコスト高。CI 遅延 |
| bundled ffmpeg (app resources に同梱) | 低 | end-user に意識させない、再現性高 | app size 増・署名/公証要件・`resolveVideoCliBinary` 拡張 |

**開発機の当面の推奨**: `homebrew-ffmpeg/ffmpeg` tap。user 操作が必要なため本 doc §6 に runbook を置く。

**プロダクト側の未決定事項**: 最終出荷形態（user 手動 / bundled / 明示不対応）は別 PR で決める。このドキュメントは技術インベントリのみ。

## 4. Fixture Inventory — 現状

### 4.1 既存

- 専用 `fixtures/` / `samples/` ディレクトリは **存在しない**
- 既存 probe テストは全て synthetic ffprobe JSON（`electron/video-export-source-metadata.test.ts` 等）
- `dist/renderer/film-lab/proof/*.mp4` は build output の graded comparison video。テスト fixture としては使わない。

### 4.2 不足

| class | 状態 | 必要性 |
|---|---|---|
| SDR BT.709 regression | ❌ ネイティブ fixture 無し | HDR policy が誤発火しないか確認するため 1 本必要 |
| HDR10 / PQ | ❌ 無し | PQ branch の fixture-backed validation 必須 |
| HLG | ❌ 無し | HLG branch の fixture-backed validation 必須 |

### 4.3 Fixture 取得オプション

#### HDR10 / PQ
- **iPhone 12 Pro 以降**: ProRes LOG + HDR10 で収録可能（iPhone 15 Pro 以降は ProRes LOG）。最も軽量で privacy-safe。
- **Sony / Canon / Panasonic HDR10 モード**: ミラーレスで HDR10 PQ 収録対応機のみ。S1II は V-Log（SDR log）なので PQ ではない。
- **公開 sample** (参考): `tears_of_steel_4k_HDR10.mp4` 等の Blender Foundation / 4KMedia の公開ファイル。再配布ライセンス注意。

#### HLG
- **iPhone**: デフォルト iOS HDR Video 出力が HLG（iPhone 12 以降、Dolby Vision Profile 8.4）。HLG だけの trim を抽出可能。
- **GoPro HERO Black**: HyperSmooth HLG 出力対応機がある。
- **Panasonic / Sony**: HLG photo/video モードを持つ機種多数。

#### SDR BT.709 regression
- 既存素材で十分。**S1II H.264 撮って出し** or **既存撮影済み .mp4** を 1-2 秒 trim すれば足りる。

### 4.4 Fixture 命名・配置規約（提案）

```
apps/desktop-film-lab-batch/
  fixtures/
    video/
      hdr/
        iphone-hlg-1s-<hash>.mov       # iPhone HLG trim
        generic-pq-1s-<hash>.mp4       # iPhone/Sony PQ trim
      sdr/
        s1ii-bt709-1s-<hash>.mp4       # S1II 撮って出し BT.709 regression
    README.md                           # 取得手順・ffprobe 期待値・出どころ
```

- 各 fixture は **1-2 秒** で十分（capability verify 目的）
- ファイルサイズ **< 5MB** を目安（git-lfs 不要の範囲）
- 被写体は人・固有情報を含まない静物 / 風景
- `README.md` に `ffprobe -show_streams -show_format -of json` の期待値を JSON snippet で残す

### 4.5 Fixture 導入前にやらないこと

- FFmpeg tone-map filter を export pipeline に wire
- PQ/HLG source に対して `prepare-sdr-mezzanine` を実際に走らせる
- export FPS 挙動の変更
- camera profile / input LUT の自動切替

## 5. Roadmap (Capability + Fixture)

```
[done]  P0-C policy pure helper + sidecar/log visibility
[done]  FFmpeg HDR capability probe + capability-aware policy downgrade
[next]  §6 runbook で開発機の HDR-capable ffmpeg を確定 (user action)
[next]  fixtures/video/{hdr,sdr}/ 配下に 3 本（HLG/PQ/SDR）を privacy-safe に追加
[next]  fixture 読み込む integration test を追加 (ffprobe → classify → policy)
[after] HDR preparation filter chain の 1 branch (PQ or HLG) を fixture-backed で wire
```

## 6. User runbook — HDR-capable ffmpeg の導入候補 (開発機のみ)

Filmtone Desktop の end-user 向け判断は別途。開発・検証用に開発機の ffmpeg を差し替える候補手順。

### 6.1 homebrew-ffmpeg tap（最短路線）

```bash
brew tap homebrew-ffmpeg/ffmpeg
brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-zimg --with-libplacebo
# 既存 ffmpeg と衝突する場合
brew link --overwrite homebrew-ffmpeg/ffmpeg/ffmpeg
ffmpeg -filters | grep -E 'zscale|libplacebo'
```

### 6.2 検証

```bash
ffmpeg -hide_banner -filters | grep -E '^\s*\.\.\. (zscale|libplacebo)'
```

両行が出力されれば capability probe は `hasZscale: true` / `hasLibplacebo: true` を返す。Filmtone Desktop 再起動後の次回 export で HDR policy が `prepare-sdr-mezzanine` へ戻る（ただし実 filter chain 実装はまだなので pixel は変わらない）。

### 6.3 Filmtone 側で override するとき

```bash
export FILM_LAB_FFMPEG_PATH=/path/to/custom/ffmpeg
export FILM_LAB_FFPROBE_PATH=/path/to/custom/ffprobe
```

`ffmpeg-cli-resolve.ts` が env override を最優先で解決する。

## 7. 関連ファイル

- 戦略計画: `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-plan-2026-04-24.md`
- 直前の handoff: `apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-workplan-handoff-2026-04-24.md`
- capability probe: `apps/desktop-film-lab-batch/electron/ffmpeg-capability-probe.ts`
- policy: `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts`
- wiring: `apps/desktop-film-lab-batch/electron/main.ts`（`resolveFfmpegHdrCapabilitiesIfNeeded`）
- sidecar Zod: `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts`

## 8. 次チャット向け handoff prompt

```text
Filmtone HDR fixture preparation を続けてください。

対象 repo:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

現在地:
- P0-C policy pure helper + sidecar/log visibility landed。
- FFmpeg HDR capability probe が追加され、hdr-pq / hdr-hlg で local ffmpeg が
  zscale/libplacebo を持たない場合は policy が defer-unknown + reason
  `ffmpeg-missing-hdr-filters` を返す。pixel 変更ゼロ。
- fixtures ディレクトリは未作成。

参照:
- apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-plan-2026-04-24.md
- apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-workplan-handoff-2026-04-24.md
- apps/desktop-film-lab-batch/docs/metadata-driven-export-quality-hdr-fixture-inventory-2026-04-24.md

user action 待ち:
- HDR-capable ffmpeg の導入（§6 runbook）
- iPhone HLG / PQ trim, S1II SDR trim の privacy-safe な確認用録画

次の作業:
1. fixtures/video/{hdr,sdr}/ を作成し、受領した 3 本を配置。
2. 各 fixture の ffprobe 期待値を README.md の JSON snippet にして固定。
3. fixtures を読み込む integration test を追加し、classify→policy を検証。
4. capability 揃って fixture 揃ったら、まず 1 branch（PQ 推奨）だけ fixture-backed で
   filter chain を wire。export FPS には触らない。

禁止事項:
- fixture 無しで PQ/HLG の実 filter chain を wire しない。
- camera profile / input LUT の自動切替をしない。
- export FPS 挙動を変えない。
- 既存 WebGPU 関連ファイル（cross filter depth / ray angle 系）を metadata 作業に混ぜない。

検証:
bun run --cwd apps/desktop-film-lab-batch test
bun run --cwd apps/desktop-film-lab-batch build:electron
bun run --cwd apps/desktop-film-lab-batch build:renderer
```
