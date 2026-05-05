# Spike: M5-H.3 Dual LUT + Intensity Slider (Desktop)

Date: 2026-05-05 JST
Branch: `feature/native-desktop-m5-h3-dual-lut-spike`
Base: `65e3f3f6` (M5-G closure + M5-C.3b doc fix)
Status: read-only design spike. No code changes in this lane.

## 0. なぜ spike が必要か

iOS は **入力 LUT (`inputLut`) + Creative LUT (`creativeLut`)** の dual
構成で、両方に `intensity` (0..1, default 1.0) を持ち WGSL pipeline で
`mix(color.rgb, lutSample, intensity)` の linear blend を行う。

Desktop は対照的に:

- **Source Profile は parametric (log curve)** で実装 (`FilmtoneSourceInputTransform`
  が Rec.709 cube に変換) — そもそも LUT スロットが無い。
- **Creative LUT は型に `intensity` を持つ** が、`FilmtoneGradePipeline.applyCreativeLutStage()`
  が intensity を読まず **1.0 pinned で焼き込んでいる**(latent bug)。
- **Sidecar は creativeLut 単一 block** のみ、iOS の `inputLut`/`creativeLut`
  分離スキーマと非互換。

`v1.4 user smoke` で「LUT intensity が効かない」「dual LUT 試したい」
と顕在化する前に、本質変更の thin slice を切り分けたい。

## 1. 現状 surface(spike 時点で確認した正本)

### Desktop

| 層 | 型 / file:line | 現状 |
|---|---|---|
| Source Profile | `CameraProfileSelection` enum @ `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceProfileCatalog.swift:21` | parametric。LUT slot 無し |
| Creative LUT binding | `CreativeLutBinding` enum @ `FilmtoneDesktop/Color/FilmtoneSavedLookSchema.swift:121` | 各 case (`.libraryRef` / `.embedded` / `.bundled`) に `intensity: Double` あり |
| EditorState | `FilmtoneDesktop/State/EditorState.swift:9` (sourceProfileSelection L35, lookSlug L17, presetStrength L13) | source/creative の binding は持つが intensity 配線済みなのは `presetStrength` のみ |
| SaveLookPayload | `FilmtoneDesktop/State/SaveLookPayload.swift:14` (M5-G.1 で lift) | `creativeLut: CreativeLutBinding?` 1 つ |
| Sidecar writer | `FilmtoneDesktop/Color/FilmtoneSidecarWriter.swift:51` | `sidecarPayload()` は creativeLut 単一 block emit |
| Pipeline 順 | `FilmtoneDesktop/Color/FilmtoneGradePipeline.swift:17` (順序 comment), `:42` apply, `:85` `applyCreativeLutStage` | sourceInput → baseGrade → … → grain → creativeLut → printStage。**creativeLut intensity = 1.0 pinned (bug)** |
| Schema version | `SavedLookEntry.schemaVersion = 2` @ `FilmtoneSavedLookSchema.swift:30-62` | decode は `decodeIfPresent` で optional 互換 |

### iOS canonical

| 層 | 名称 / file:line |
|---|---|
| Schema | `Phase0ProjectLut` @ `packages/film-lab-core/src/phase0-schema.ts:177-222` ( `inputLut` L177, `creativeLut` L197, legacy `lut` → `creativeLut` normalize L222) |
| Sidecar | `FilmtoneExportSidecarV1` @ `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift:196` (`inputLut: SidecarLutRef?` + `creativeLut: SidecarLutRef?`) |
| `SidecarLutRef` field | `size`, `intensity`, `sourceHash`, `bundledSlug`, `bundledPackId` |
| Shader blend | `packages/film-lab-renderer/src/webgpu/shaders/filmlab.frag.wgsl.ts:145-153` (LUT1) / `:213-225` (LUT2) — `mix(color.rgb, lutSample, intensity)` |
| Pipeline 順 | media → LUT1 (intensity blend) → exposure → contrast → … → soft-shaper → LUT2 (intensity blend) → print stage |

## 2. 推奨アーキテクチャ

### 2.1 命名・スキーマは iOS に揃える(Source Profile は残す)

- **新規 `InputLutBinding`** を `CreativeLutBinding` の構造クローンで導入(case
  3 つ + `intensity: Double`)。Generic 化しない — 焼かない方が
  diff/grep がしやすく、Codable schema 互換も追いやすい。
- **`CameraProfileSelection` (parametric) は deprecate しない**。Source
  profile は「カメラの色空間 normalize」で意味的に input LUT の
  parametric 版。新 `inputLut` は **任意の override** として coexist:
  - `inputLut == nil` の時は parametric source profile が動く(現状互換)
  - `inputLut != nil` の時は parametric stage を skip し、CIColorCubeWithColorSpace
    を入れる
- **Sidecar field 名も iOS と同じ `inputLut` / `creativeLut`**。Desktop ↔
  iOS の round-trip を将来 v1.6 以降で取りに行く時、ここで揃えておく
  と migration が要らない。
- `intensity` 配置は iOS 通り **各 LUT binding 内**(slider 2 本)。

### 2.2 intensity slider の置き場所

- **Quick Look surface**: Creative LUT intensity slider(既存 `presetStrength`
  とは別物 — preset 全体の strength は残す)
- **Advanced surface**: Camera (Input) LUT intensity slider
- shader 側は CIColorCubeWithColorSpace の出力を `CIBlendWithMask` か
  `mix` 相当の `CIColorMatrix`+`CISourceOverCompositing` で `intensity`
  blend する。creativeLut 側は **bug fix として優先**。

### 2.3 pipeline 順序(変更案)

```
sourceInput (parametric, only if inputLut == nil)
  → inputLut stage (CIColorCubeWithColorSpace, intensity blend)   ← NEW
  → baseGrade
  → filmCompression
  → edgeOptics
  → glowFamily
  → vignette
  → grain
  → creativeLut stage (intensity blend FIX)                       ← FIX
  → printStage
```

iOS と stage 順序は意味的に等価(input 系列 → grade → creative LUT →
print)。

## 3. 変更対象ファイル(優先度順)

| # | ファイル | 変更概要 |
|---|---|---|
| 1 | `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift` | `applyCreativeLutStage` の intensity 配線(bug fix)、`applyInputLutStage` 追加 |
| 2 | `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSavedLookSchema.swift` | `InputLutBinding` 追加、`SavedLookEntry` に `inputLut: InputLutBinding?` 追加、`schemaVersion: 3` |
| 3 | `apps/filmtone-desktop-macos/FilmtoneDesktop/State/SaveLookPayload.swift` | `inputLut: InputLutBinding?` 追加 |
| 4 | `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift` | `inputLutBinding: InputLutBinding?` 追加、`sourceProfileSelection` は維持 |
| 5 | `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSidecarWriter.swift` | sidecar に `inputLut` block 追加(iOS の `SidecarLutRef` field 名に揃える) |
| 6 | `apps/filmtone-desktop-macos/FilmtoneDesktop/State/FilmtoneSavedLookStore.swift` | load/save の inputLut path |
| 7 | `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/...` (LibraryViewModel + Quick/Advanced panel) | Camera LUT picker UI、creativeLut intensity slider、inputLut intensity slider |
| 8 | `apps/filmtone-desktop-macos/Verify/main.swift` + `run.sh` SOURCES | dual LUT round-trip + intensity blend regression test |
| 9 | `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift` (M5-G.1 産物) | sidecar 入力に inputLut binding を渡す配線 |

## 4. Migration / sidecar 互換リスク

| リスク | 影響 | 対処 |
|---|---|---|
| 既存 `schemaVersion: 2` sidecar に `inputLut` 無し | read 時 nil 想定 | `decodeIfPresent` で optional → 無害(既に同パターンで `creativeLut` を扱っている) |
| `creativeLut intensity != 1.0` を持つ既存 SavedLookEntry | 現在は intensity 無視されているので「bug fix で見え方が変わる」 | 既存 entry の SHA + intensity を migration 起動時に scan、intensity != 1.0 がある場合は changelog で behavior change を明記。silent fix にしない |
| iOS との sidecar field 名互換 | 一致しないと将来の cross-platform sync で再 migration が必要 | iOS と同じ `inputLut` / `creativeLut` + `SidecarLutRef.{size,intensity,sourceHash,bundledSlug,bundledPackId}` を踏襲 |
| `sourceProfileSelection` (parametric) と `inputLutBinding` の競合 | preview/export で 2 重適用される事故 | `inputLutBinding != nil` の時は parametric source stage を **skip**(片方のみ動く invariant を pipeline test で pin) |
| bundled LUT catalog の slug 衝突 | LUT1/LUT2 で同 slug が出ると catalog lookup が曖昧 | `BundledLutCatalog` を slot ごとに 2 つ (`InputLutCatalog` / `CreativeLutCatalog`) に分けるか、slug の prefix で disambiguate |
| 用語ロック | CLAUDE.md §6: `Look` は Stone / Urban Creative LUT Pack 文脈専用、`Preset` と `Look` を混同しない | この lane の rename も含め、`Look` は touch しない。新規型は `InputLutBinding` (Look ではなく LUT) |

## 5. Commit 分割案 (3 commits)

| # | Commit | 含まれる変更 | gate |
|---|---|---|---|
| C1 | `fix(macos): wire creative LUT intensity through gradePipeline` | `FilmtoneGradePipeline.applyCreativeLutStage` の intensity 配線、Verify に creativeLut intensity blend test 追加。スキーマは触らない | **v1.4 gate 必須**(latent bug fix) |
| C2 | `feat(macos): add inputLutBinding schema + payload + state` | `InputLutBinding` 導入、`SavedLookEntry`(schemaVersion 2→3)・`SaveLookPayload`・`EditorState` に inputLut 追加、Codable round-trip & v2→v3 decode 互換 test。pipeline / UI は **触らない**(field を持つだけの thin slice) | v1.5 |
| C3 | `feat(macos): wire input LUT stage + sidecar block + UI pickers` | `FilmtoneGradePipeline.applyInputLutStage` 追加(parametric stage の skip 含む)、`FilmtoneSidecarWriter` に inputLut block(iOS SidecarLutRef field 名)、Quick/Advanced UI に Camera LUT picker + intensity slider 2 本 | v1.5 |

C2 を schema-only の thin slice にすることで、UI と pipeline 変更が
入る C3 の review surface が schema 変更で膨らまない(M5-G.1 と同じ
責務分離原則)。

## 6. v1.4 gate に含めるべきか / v1.5 でよいか

| 案件 | 推奨 | 理由 |
|---|---|---|
| **C1 (creative LUT intensity 配線 bug fix)** | **v1.4 gate** | 既存 UI に intensity 概念が露出していなくても、SavedLookEntry は intensity 値を持っている。v1.4 で landing する dual LUT 議論より先に「持っている値が効かない」状態の方を先に閉じる。test surface 小、regression 範囲は creativeLut stage のみ |
| **C2 + C3 (Dual LUT 本体)** | **v1.5** | 新 schema、新 UI、Source Profile parametric との coexistence — 全て新機能扱い。v1.4 は M5-H smoke defects (chrome layout / adjust library) と notarize 提出が gate なので、新 surface を相乗りさせると test 計画が膨らむ |

ただし C1 を v1.4 gate に入れると **既存 SavedLookEntry の見え方が
変わる**(intensity != 1.0 を持つ entry がある場合)。changelog 明記必須。
silent fix にすると `feedback_no_silent_stream_redefine` 違反相当の
体験変化を user に押し付けることになる。

## 7. 実装しないこと(本 spike scope outside)

- WebGPU / WebGL renderer 側 (`packages/film-lab-renderer/`) の dual LUT
  対応 — 既に iOS canonical で動いているので Desktop が追随側
- iOS 側の sidecar field 変更 — iOS は既に dual schema、Desktop が追随側
- `CameraProfileSelection` (parametric) の deprecate — coexist 戦略を
  選んだので v1.5 では触らない
- LUT pack 製品化 (`BundledLutCatalog` 拡充) — 別 lane

## 8. Verification

このコミットは doc only。`bun run verify:macos` は不要。
C1〜C3 を実装する後続 lane では Verify に以下を追加する:

- creativeLut intensity blend regression(0.0 / 0.5 / 1.0 で出力差分が
  monotonic に変化することを pin)
- SavedLookEntry v2 → v3 decode 互換
- `inputLutBinding != nil` の時 parametric source stage が skip される
  invariant
