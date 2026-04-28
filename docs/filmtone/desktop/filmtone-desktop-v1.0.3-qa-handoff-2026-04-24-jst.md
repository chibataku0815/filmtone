# Filmtone Desktop v1.0.3 候補 — 目視 QA 手順書

- 日付: 2026-04-24 JST
- 対象バージョン: `desktop-v1.0.2..HEAD`（29 commits / 110 files / +12446 -1225）
- 対象ビルド: `apps/desktop-film-lab-batch` 開発ビルド（まだ `1.0.2` のまま。QA 合格後に bump）
- リリース前提条件: 本書のすべての「期待結果」に到達すること

## 0. 前提と除外

- 本書は **Desktop 目視で確認できる変更** のみを対象とする。
- iOS 側の変更（portrait orientation 修正 / compare preview / mezzanine foundation / neutral soft finish）は対象外。
- HDR → SDR の **実変換** はまだ検知 / 方針 / 通知レイヤーまで（fixture harness + 設計 doc 止まり）。本 QA でも実変換出力は合否条件に含めない。
- Cross Filter / Bloom / Halation の深度系パラメータの一部は JSON レベルの hidden control（`crossFilterDepthGain` 等）で、UI スライダーは無い。動きとして「Depth/光学メタデータで自然に変わるか」を見る。

## 1. 事前準備

### 1.1 環境

- [ ] Apple Silicon / macOS 11+
- [ ] 開発ビルドを起動できる（`apps/desktop-film-lab-batch` の `bun run dev` 系 or パッケージ版）
- [ ] 前バージョンの設定リセット: 初回起動挙動を見るため、可能なら user data ディレクトリを一時退避

### 1.2 HDR 変換環境

- [ ] **A: 通常環境**（HDR→SDR 変換 filter が無い環境）。ユーザー向け注意文が出ることを確認する。
- [ ] **B: HDR 変換対応環境**（`zscale + tonemap` または `libplacebo` が使える環境）。注意文が出ず、自動で SDR mezzanine を作ることを確認する。
- [ ] ユーザー向け UI に install command / internal filter 名 / fixture doc link が出ないことを確認する。

### 1.3 テスト素材（最低この組合せを揃える）

| ラベル | 内容 | 確認目的 |
|-------|-----|---------|
| `SDR-LAND` | SDR Rec.709 / 横長 / 24fps / EXIF に camera/lens あり | 既定フロー / 光学メタデータ検出 |
| `SDR-PORT` | SDR / **縦持ち撮影**（rotation 90° or 270° がコンテナにある） | プレビュー自動回転 |
| `HDR-PQ` | HDR PQ（`smpte2084`）な mp4/mov | HDR 検知 + 非ブロッキング警告 |
| `HDR-HLG` | HDR HLG（`arib-std-b67`） | HLG 検知 |
| `WIDE-UNK` | Rec.2020 だが transfer 不明 or 特殊 LUT な素材 | `wide-gamut-unknown` 分類 |
| `NO-META` | Camera / Lens 情報が無い素材（古いスマホ等） | 65° HFOV フォールバック |

> PQ / HLG が手元に無い場合は Blackmagic / ATEM / iPhone HDR の撮って出しで代用可。fixture doc は `apps/desktop-film-lab-batch/docs/hdr-fixture-inventory.md` 参照。

## 2. 起動と初期状態（Default look change）

### 2.1 初期プリセットが **Neutral / Clean Base** になっているか

- [ ] 起動直後、プリセット一覧で **選択状態が "Neutral" "Clean Base"** になっている
  - 実装: `packages/film-lab-core/src/presets.ts:711` / `createFilmtoneDefaultParams()` at 663-668
- [ ] 起動直後のプレビューが「彩度高め / コントラスト強」な Cinematic 系ではなく、**ニュートラル + soft finish**（僅かに bloom と halation が効いたフラット寄り）に見える
- [ ] `Bloom Strength ≈ 0.22` / `Bloom Threshold ≈ 0.72` / `Halation Intensity ≈ 0.10` 相当に見える（具体の数値は Effects パネルのスライダーで確認可）

### 2.2 Reset（Numpad `0` or プリセット "Neutral" タップ）挙動

- [ ] 任意の Look（例: Cinematic）に切り替えた後、**Numpad `0`** を押すと Neutral に戻る
- [ ] 戻った状態のパラメータが「起動直後」と同一（Bloom / Halation / Diffusion が soft finish 値）
- [ ] ユーザーが手動で触った値もクリアされる

### 2.3 Import fallback（プリセット情報の無い grade JSON を読む）

- [ ] 他クリップから書き出した sidecar を取り込む or プリセット名の無い旧 JSON を食わせる
- [ ] **Neutral + soft finish** が適用される（完全 neutral ゼロ値ではない）
  - 実装: `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts:55-60` の `FILMTONE_DEFAULT_BASE_PRESET`

### 2.4 プリセットバーの並び順

- [ ] 並びが **Utility（Neutral）→ Film Stock 9種 → Look（Cinematic 他）** の順
- [ ] カテゴリ間に横の divider が見える
- [ ] アクティブプリセットに amber のハイライトリングが付く
  - 実装: `packages/film-lab-ui/src/PresetBar.tsx:56-99` / `PRESET_BUTTONS` @ `presets.ts:704-721`

## 3. カメラ光学メタデータの intake & 表示

### 3.1 ソース情報ラベル（ビデオドロップ直後）

- [ ] `SDR-LAND` を読み込むと、**ソース情報行に以下の形式のラベル** が表示される
  ```
  {Camera Make} {Model} · {Lens} · {focal}mm eq · HFOV {hfov}deg · {source}
  ```
  - 例: `Sony A7R4 · Sony FE 35mm f/1.4 · 35.0mm eq · HFOV 65.0deg · metadata`
  - 実装: `apps/desktop-film-lab-batch/src/renderer/video-probe-label.ts:5-30`
- [ ] `source` が `metadata` / `assumed` / `manual` のいずれかを表示
- [ ] `NO-META` を読み込むと `source=assumed` で **65° HFOV フォールバック** 表示
  - 定数: `RAY_ANGLE_FALLBACK_HFOV_DEG` @ `rayAngleOptics.ts:11`

### 3.2 書き出し時の sidecar への保存

- [ ] `SDR-LAND` を書き出し、同ディレクトリに **`<output>.filmtone-session.json`** が生成される
  - 実装: `export-metadata-session.ts:94-95`
- [ ] 当該 JSON の `cameraOptics` に以下キーが埋まる:
  ```json
  {
    "source": "metadata",
    "fxPx": ..., "fyPx": ...,
    "cxPx": ..., "cyPx": ...,
    "fovXDeg": ..., "fovYDeg": ...,
    "focalLength35mm": 35.0,
    "lensModel": "...",
    "cameraMake": "...",
    "cameraModel": "..."
  }
  ```

## 4. ソース動画メタデータ（色 / HDR / 回転 / FPS）

### 4.1 縦持ち素材のプレビュー向き（`SDR-PORT`）

- [ ] 縦撮り動画をドロップ → **プレビューが縦**（90° or 270° 正しく適用）
- [ ] 書き出し後の sidecar `sourceVideoMetadata.display.rotationDeg` に正しい値
- [ ] `display.source` が `ffprobe-side-data` or `ffprobe-tags` になっている

### 4.2 Color / HDR 分類（`SDR-LAND` / `HDR-PQ` / `HDR-HLG` / `WIDE-UNK`）

- [ ] 書き出し後の sidecar `sourceVideoMetadata.colorClass` が以下:
  - `SDR-LAND` → `sdr-bt709`
  - `HDR-PQ` → `hdr-pq`
  - `HDR-HLG` → `hdr-hlg`
  - `WIDE-UNK` → `wide-gamut-unknown` or `unknown`
- [ ] `sourceVideoMetadata.color.colorTransfer` が PQ は `smpte2084`、HLG は `arib-std-b67`

### 4.3 フレームレート信頼度

- [ ] VFR 系 or 壊れかけのクリップで `sourceVideoMetadata.timing.sourceFrameRateTrusted` が `false` になる
- [ ] `trustReason` が `missing-or-invalid-rate` / `rates-diverged` / `within-absolute-tolerance` / `within-relative-tolerance` のいずれか

## 5. HDR preparation policy + tone-map fallback

> **ここが今回の最大の目視ポイント。** HDR 対応環境では自動で SDR mezzanine を作り、非対応環境ではユーザーに開発者向け command を見せず、非ブロッキングの注意だけを出す。

### 5.1 A（HDR 変換 filter 無し）+ `HDR-PQ` 読み込み時

- [ ] ソース読込直後、**HdrPolicyNotice** が琥珀色の callout として表示される
  - 実装: `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx`
- [ ] タイトル（JA）: **「HDR動画を読み込みました」**
- [ ] 本文（JA）: **「この環境では、HDR動画を標準のSDR動画として正確に変換できない場合があります。書き出しは続行できますが、他のアプリで見ると明るさや色が元動画と違って見えることがあります。正確な色で書き出したい場合は、カメラアプリや編集アプリでSDR動画に変換してから読み込んでください。」**
- [ ] UI には `ffmpeg` / `zscale` / `libplacebo` / `brew` / fixture doc link が表示されない

### 5.2 非ブロッキング確認（A のまま）

- [ ] 警告が出ていても **書き出し自体は走る**（ブロックしない）
- [ ] 書き出し後 sidecar `hdrPreparationPolicy.reason` が `ffmpeg-missing-hdr-filters`
- [ ] `hdrPreparationPolicy.strategy` が `defer-unknown` 系
- [ ] 出力自体は source を素通しで保存される（tone-mapped SDR にはなっていない）

### 5.3 B（HDR 変換対応環境）で同じ `HDR-PQ` を読む

- [ ] `HdrPolicyNotice` **が出ない**
- [ ] sidecar `hdrPreparationPolicy.reason` が `source-is-hdr-pq` or `source-is-hdr-hlg` になり、`ffmpeg-missing-hdr-filters` では **ない**
- [ ] `strategy` が `prepare-sdr-mezzanine`
- [ ] `filterSelection` が sidecar に入り、書き出しログに `HDR→SDR tone-map ... mezzanine` が出る
- [ ] 出力を目視し、HDR 素材が極端に白飛び / 低彩度 / 黒つぶれしていない

### 5.4 `HDR-HLG` / `WIDE-UNK` / `SDR-LAND` の差分

- [ ] `HDR-HLG` で A だと同じく `ffmpeg-missing-hdr-filters`、B で `source-is-hdr-hlg` + tone-map mezzanine
- [ ] `WIDE-UNK` で `wide-gamut-transfer-unknown` or `source-color-unknown`
- [ ] `SDR-LAND` は `source-is-sdr-bt709` で HdrPolicyNotice は **出ない**

## 6. Cross Filter（depth-aware + ray-angle）

> Pro モード限定。Effects → Cross カード。

### 6.1 基本表示

- [ ] Effects パネル → **Cross カード** が見える（Pro モードに切り替え後）
- [ ] "**Cross Filter**" トグル ON でアドバンスド不要でも streak が出る
- [ ] 「Show advanced」で Strength / Points (4/6/8) / Angle / Length / Threshold / Chromatic / Source Size / Randomness / Streak Spacing が出揃う
  - 実装: `FilmLabControlPanelCore.tsx:1103-1140+`

### 6.2 Depth-aware な変化（目視）

- [ ] Depth track を有効にできる素材で、**手前の被写体と背景で streak の長さ/強度が違う** ことを目視できる
- [ ] Depth を `0` に落とす → 深度変調が消え、均一 streak に戻る
- [ ] v1.0.2 時点の build と A/B 比較して、**streak の広がり方が画面端でより自然（均一ではない）**

### 6.3 Ray-angle によるフレーム端差（`SDR-LAND` + `NO-META`）

- [ ] `SDR-LAND`（65° HFOV metadata 有り）で強い点光源をフレーム**端**に置いて書き出し → streak が中央より強く / 長く出る
- [ ] `NO-META`（65° HFOV フォールバック）で同様に撮った素材で同じ傾向（fallback が破綻しない）
- [ ] 今回 fix された ray-angle contract 前後で、**フレーム四隅の streak が不自然に削れていないか**（96f5d437 の fix ポイント）

## 7. 光学ディフュージョン / Bloom / Halation（depth coupling）

UI スライダーは従来通り（Glow カード内 Bloom / Halation、Mist カード Diffusion）。深度係数は shader 側 hidden。

- [ ] Glow カードの Bloom トグル / Threshold / Radius が動く
- [ ] Halation の Intensity / Spread / Hue が動く
- [ ] Mist カードの Diffusion が動く
- [ ] Depth track を持つ素材で、**近景の Bloom 強度が背景より控えめ** など「深度駆動」と分かる挙動が出る（v1.0.2 との A/B で判定）
- [ ] Depth を無効にしても全体は破綻しない（fallback がある）

## 8. Progressive loading / Quality badge

- [ ] 素材ドロップ後にプレビュー角に **Quality badge**（FHD / 4K / "Converting…" / "Enhancing quality…"）が出る
  - 実装: `apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts`, `QualityBadge.tsx`
- [ ] mezzanine → フル解像度 への段階遷移中に badge が更新される
- [ ] badge 表示中もグレーディングが操作可能

## 9. Export sidecar 全体検査（`<output>.filmtone-session.json`）

書き出し 1 本で sidecar を開き、以下キーが **すべて埋まっている** ことをチェック:

- [ ] `cameraOptics`（§3.2 参照）
- [ ] `sourceVideoMetadata.display` / `.color` / `.timing` / `.colorClass`（§4 参照）
- [ ] `hdrPreparationPolicy.strategy` / `.reason`（§5 参照）
- [ ] `grade` / `preset`（Neutral + soft finish の数値が入っていること）
- [ ] JSON が schema validation を通る（開発者モードでコンソール error が無い）
  - 実装 refs: `export-metadata-session.ts` / `schema.ts` / `params.ts`

## 10. Regression チェック（既存機能が壊れていないこと）

- [ ] 以前の grade JSON をインポートしても **値が保持**され、new default は overwrite しない
- [ ] Film Stock 9 プリセットが全部選択可能、選択時にパラメータがプリセット通りに適用される
- [ ] Cinematic プリセットが v1.0.2 と見た目同じ（回帰していない）
- [ ] 連続書き出し（同ディレクトリに複数本）で sidecar が上書きされず、各動画ごとに独立
- [ ] 書き出し中に cancel / 別 session 開始 → v1.0.2 で入った session isolation が維持されている
- [ ] `ffmpeg` が `PATH` に無い状態で起動 → 既存の missing-ffmpeg UI が従来通り出る（HDR notice と競合しない）

## 11. 合否判定

- **必須**: §2 / §3.1 / §4.1 / §5.1 / §5.3 / §10 すべて合格
- **推奨（release 可能判定）**: §5.2 / §5.4 / §6.1 / §9 合格
- **任意（v1.0.3 では fail しても可）**: §6.2, §6.3, §7 の depth A/B 比較（微妙な差のため個体ごとに判定）

不合格のみ issue 化して gate する。合格後に:

1. `apps/desktop-film-lab-batch/package.json` を `1.0.3` に bump
2. `apps/desktop-film-lab-batch/RELEASE_NOTES-v1.0.3.md` を起草（`RELEASE_NOTES-v1.0.2.md` のフォーマット踏襲）
3. 24 未 push commit を push
4. DMG ビルド + signed + notarized + checksum
5. `desktop-v1.0.3` tag + GitHub Release + Blob upload + `/film-lab/download` 告知
6. Desktop v1.0.1 banner 統合レーンと合流（neutral soft finish のアナウンス）

## 12. 参考: 本 release で触らない範囲（QA 対象外の明示）

- HDR → SDR の実際の tone-mapping 出力（fixture harness 設計までで、S-6 以降）
- iOS v1.0 / v1.1（別 track）
- Cross Filter の hidden depth/angle/edge gain スライダー化（今は shader baked）
- Signature Pack content 残り 5/8

---

## Appendix A — 実装ファイル早見表

| 領域 | 主ファイル |
|-----|---------|
| Default preset + soft finish | `packages/film-lab-core/src/presets.ts:652-721` |
| Params contract | `packages/film-lab-core/src/params.ts` |
| Grade schema | `packages/film-lab-core/src/schema.ts` |
| Preset UI | `packages/film-lab-ui/src/PresetBar.tsx`, `PresetSearchSelect.tsx` |
| Effects panel | `packages/film-lab-ui/src/FilmLabControlPanelCore.tsx:965-1140+` |
| Cross filter shader | `packages/film-lab-renderer/src/webgpu/shaders/cross-filter-streak.frag.wgsl.ts` |
| Ray-angle optics | `packages/film-lab-renderer/src/webgpu/rayAngleOptics.ts` + `.test.ts` |
| Composite uniforms | `packages/film-lab-renderer/src/webgpu/compositeUniforms.ts` |
| Probe label | `apps/desktop-film-lab-batch/src/renderer/video-probe-label.ts` |
| Export metadata session | `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts` |
| Export pipeline | `apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts` |
| HDR policy notice | `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx` |
| HDR i18n | `apps/desktop-film-lab-batch/messages/ja.json`, `en.json` |
| Progressive load | `apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts` |
