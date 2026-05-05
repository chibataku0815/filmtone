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
| Sidecar writer | `FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift:51` | `sidecarPayload()` は creativeLut 単一 block emit |
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

### 2.1 input LUT は project state surface のみ。Saved Look library には載せない

- **input LUT は source-dependent normalization** として扱う(iOS / Desktop
  canonical 共通の意味論)。「このカメラ素材を normalize するための LUT」
  であって「creative grade preset」ではない。
- したがって **inputLut が乗る surface は次の 4 つに限定**:
  1. `EditorState`(project の現在 input LUT 選択)
  2. project state(open file ごとに保持される source-side state)
  3. export request(`FilmtoneStillExportRequest` 等の export 直前 payload)
  4. sidecar(export 出力に伴う `.filmtone.json` block)
- **`SavedLookEntry` / `SaveLookPayload` / `LibraryViewModel` 保存 payload
  には inputLut を載せない**。Saved Look library は creative LUT preset の
  library であり続ける。`inputLut` を Saved Look に焼くと「camera
  normalize 設定が creative preset に紛れ込む」semantic 破綻になる。
- 結果として **`SavedLookEntry.schemaVersion` 2→3 の bump はこの lane では
  行わない**。Saved Look 側は creativeLut 1 本のままで sidecar 側だけ
  iOS 互換の dual block にする。
- **新規 `InputLutBinding`** を `CreativeLutBinding` の構造クローンで導入(case
  3 つ + `intensity: Double`)。Generic 化しない — 焼かない方が
  diff/grep がしやすく、Codable schema 互換も追いやすい。型は project
  state / export request / sidecar 内でのみ使う。
- **`CameraProfileSelection` (parametric) は deprecate しない**。Source
  profile は「カメラの色空間 normalize」で意味的に input LUT の
  parametric 版。新 `inputLut` は **任意の override** として coexist:
  - `inputLut == nil` の時は parametric source profile が動く(現状互換)
  - `inputLut != nil` の時は parametric stage を skip し、CIColorCubeWithColorSpace
    を入れる
- **Sidecar field 名は iOS と同じ `inputLut` / `creativeLut`**。Desktop ↔
  iOS の round-trip を将来 v1.6 以降で取りに行く時、ここで揃えておく
  と migration が要らない。Saved Look schema は **iOS 側も creativeLut
  単独** なので bump 不要。
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
| 1 | `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift` | `applyCreativeLutStage` の intensity 配線(bug fix)、`applyInputLutStage` 追加(`inputLutBinding != nil` の時 parametric source stage を skip) |
| 2 | `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSavedLookSchema.swift` | **`InputLutBinding` の宣言のみ**(新型を Color/ に置く)。`SavedLookEntry` は touch しない、`schemaVersion` も 2 のまま |
| 3 | `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift` | `inputLutBinding: InputLutBinding?` 追加、`sourceProfileSelection` は維持 |
| 4 | `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift` | sidecar に `inputLut` block 追加(iOS の `SidecarLutRef` field 名に揃える)。creativeLut block は既存通り |
| 5 | `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift` (M5-G.1 産物) | export request 構築時に EditorState から `inputLutBinding` を取って sidecar writer に渡す配線 |
| 6 | `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/...` (Quick/Advanced panel) | Camera (Input) LUT picker UI + intensity slider、creativeLut intensity slider。**LibraryViewModel の保存 payload には inputLut を含めない**(Saved Look は creative LUT only) |
| 7 | `apps/filmtone-desktop-macos/Verify/main.swift` + `run.sh` SOURCES | creativeLut intensity blend regression、`inputLutBinding != nil` 時の parametric stage skip invariant、sidecar dual block round-trip |

**touch しない**:
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/SaveLookPayload.swift` — Saved Look library payload は creativeLut のみ
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSavedLookStore.swift` — load/save 経路は creativeLut のみ
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/.../LibraryViewModel.*` の保存 payload 構築側

## 4. Migration / sidecar 互換リスク

| リスク | 影響 | 対処 |
|---|---|---|
| 既存 sidecar(creativeLut のみ)を読む | sidecar reader 側はまだ無いが、将来 round-trip を取る時に旧 sidecar には `inputLut` が無い | `decodeIfPresent` で optional → 無害(既に creativeLut が optional) |
| `creativeLut intensity != 1.0` を持つ既存 `SavedLookEntry` | 現在は intensity 無視されているので「bug fix で見え方が変わる」 | 既存 entry の SHA + intensity を起動時 / migration 時に scan、intensity != 1.0 がある場合は changelog で behavior change を明記。silent fix にしない |
| iOS との sidecar field 名互換 | 一致しないと将来の cross-platform sync で再 migration が必要 | iOS と同じ `inputLut` / `creativeLut` + `SidecarLutRef.{size,intensity,sourceHash,bundledSlug,bundledPackId}` を踏襲 |
| `sourceProfileSelection` (parametric) と `inputLutBinding` の競合 | preview/export で 2 重適用される事故 | `inputLutBinding != nil` の時は parametric source stage を **skip**(片方のみ動く invariant を pipeline test で pin) |
| bundled LUT catalog の slug 衝突 | input LUT と creative LUT で同 slug が出ると catalog lookup が曖昧 | `BundledLutCatalog` を slot ごとに 2 つ (`InputLutCatalog` / `CreativeLutCatalog`) に分けるか、slug の prefix で disambiguate |
| `SavedLookEntry.schemaVersion` を不必要に bump しないこと | bump すると iOS 側との Saved Look schema 整合(iOS も creativeLut 単独)が崩れ、Library migration が雪だるま化する | この lane では `schemaVersion: 2` 維持。inputLut は project state / sidecar surface のみ |
| 用語ロック | CLAUDE.md §6: `Look` は Stone / Urban Creative LUT Pack 文脈専用、`Preset` と `Look` を混同しない | この lane の rename も含め、`Look` は touch しない。新規型は `InputLutBinding` (Look ではなく LUT) |

## 5. Commit 分割案 (3 commits)

| # | Commit | 含まれる変更 | gate |
|---|---|---|---|
| C1 | `fix(macos): wire creative LUT intensity through gradePipeline` | `FilmtoneGradePipeline.applyCreativeLutStage` の intensity 配線、Verify に creativeLut intensity blend test 追加。スキーマは触らない | **v1.4-preferred** thin correctness fix(下記 §6 参照) |
| C2 | `feat(macos): add InputLutBinding type + EditorState surface` | `InputLutBinding` を `Color/FilmtoneSavedLookSchema.swift` に宣言(型のみ)、`EditorState` に `inputLutBinding: InputLutBinding?` 追加。**SavedLookEntry / SaveLookPayload / SavedLookStore は touch しない**、`schemaVersion` は 2 のまま。pipeline / sidecar / UI も触らない thin slice | v1.5 |
| C3 | `feat(macos): wire input LUT stage + sidecar block + UI pickers` | `FilmtoneGradePipeline.applyInputLutStage` 追加(parametric source stage の skip 含む)、`Export/FilmtoneSidecarWriter` に inputLut block(iOS `SidecarLutRef` field 名)、`ExportCoordinator` の export request 構築側に EditorState の inputLut 配線、Quick/Advanced UI に Camera LUT picker + intensity slider 2 本(LibraryViewModel 保存 payload には触れない) | v1.5 |

C2 を「型 + EditorState 1 field」だけの thin slice に絞ることで、
pipeline / sidecar / UI が入る C3 の review surface が schema や Library
の話で膨らまない(M5-G.1 と同じ責務分離原則)。

## 6. v1.4 gate に含めるべきか / v1.5 でよいか

| 案件 | 推奨 | 理由 |
|---|---|---|
| **C1 (creative LUT intensity 配線 bug fix)** | **v1.4-preferred thin correctness fix。低リスクなら notarize 前に実装推奨** | hard gate(必須)とは扱わない。`SavedLookEntry` は intensity 値を持っているのに pipeline が無視している latent correctness gap で、test surface は creativeLut stage 単独・Verify regression 1〜2 件で囲える。M5-H smoke 完了後、notarize submission の直前に **diff < 30 行** で着地できる場合は入れる。pipeline regression が膨らむなら無理せず v1.5 へ送る |
| **C2 + C3 (Dual LUT 本体)** | **v1.5** | 新型 + 新 pipeline stage + 新 UI + Source Profile parametric との coexistence — 全て新機能扱い。v1.4 は M5-H smoke defects (chrome layout / adjust library) と notarize 提出が gate なので、新 surface を相乗りさせると test 計画が膨らむ |

C1 を v1.4 に入れる場合、**既存 `SavedLookEntry` の見え方が変わる**
(intensity != 1.0 を持つ entry がある場合)ので changelog 明記必須。
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
- `inputLutBinding != nil` の時 parametric source stage が skip される
  invariant
- sidecar dual block round-trip(`inputLut` + `creativeLut` 両方が writer
  で emit され、iOS `SidecarLutRef` schema と field 名が一致する)
- `SavedLookEntry` の Codable は **touch しない**(回帰しない確認のため
  既存 schemaVersion 2 round-trip test を残す)
