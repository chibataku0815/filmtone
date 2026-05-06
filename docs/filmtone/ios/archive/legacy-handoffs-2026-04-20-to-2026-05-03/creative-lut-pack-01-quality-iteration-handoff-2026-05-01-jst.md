# Filmtone iOS — Creative LUT Pack 01 品質改善引き継ぎ
2026-05-01 JST / next-chat handoff

---

## 0. この doc の目的

直前 chat (`groovy-dewdrop` plan)で Creative LUT Pack v1.4 (Pack 01) の **配管 PR + 一次コンテンツ bake** まで実装した。実機 (千葉工の iPhone, iOS 26) で確認した結果、**ビルドは通った**が CD (= ユーザー本人) から「クオリティが低い、破綻も見られる」とフィードバック。次 chat で **Pack 01 の color / 光学チューニングを CD 視点で本格的に詰める** ための完全引き継ぎ。

> **重要**: 実装機構(配管・サイドカー・pbxproj・slug naming・lens-filter override 設計)は完成済。**色・光学値そのものが CD 基準を満たしていない**のがこの先の課題。次 chat は color science / lens character iteration が主戦場。

---

## 1. リポジトリ・前提

| 項目 | 値 |
|---|---|
| Repo | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` (standalone, GitHub `chibataku0815/filmtone`) |
| Brand identity | Filmtone iOS = portrait/動画向け film-tone iOS app。lens character (halation / bloom / diffusion / glow trio / grain) が他社 LUT pack に対する差別化 |
| Active feature lane | v1.4 Creative LUT Pack 01(本 doc)+ Look→.cube export(別 lane、未着手)+ Pack 02+(将来)|
| v1.3 release rail | archive 完了済、ASC submit 状況は life の `scripts/check-filmtone-release-truth.sh` で要確認 |
| パッケージマネージャ | **bun 必須**(npm 禁止、life CLAUDE.md §パッケージマネージャ)|
| User role | CD = chibatakumi(日本語、英語可)。色は **CD signoff** 必須 |
| Working directory note | `apps/capacitor-film-lab-ios/` から bash 実行する場合 `git status` のパスは `../../` プレフィクス付き相対表示になる(repo root から走らせるのが推奨) |

CLAUDE.md ポインタ:
- repo root: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/CLAUDE.md`
- iOS subtree: `apps/capacitor-film-lab-ios/CLAUDE.md`
- life: `/Volumes/SamsungPortableSSDX5001/documents/life/CLAUDE.md`
- 元 plan(直前 chat): `/Users/chibatakumi/.claude/plans/volumes-samsungportablessdx5001-filmton-groovy-dewdrop.md`

---

## 2. 直前 chat で完了した内容(全部)

### 2.1 Phase 0 — TS schema additive(commit `9d735ff` で user が pre-committed)
- `packages/film-lab-core/src/native-bridge.ts` の `ParsedCubeLut` に optional `bundledSlug?: string` / `bundledPackId?: string`
- `packages/film-lab-core/src/ios-phase0.ts` の `iosPhase0SerializableLutSchema` に同じ 2 fields(zod `.optional()`)
- `serializeCubeLut()` / `createIosPhase0SerializableLut()` / `buildPhase0ExportRequest`'s `toTransportLut` で provenance thread-through
- このコミットだけ既に main にある(他はすべて working tree)

### 2.2 Phase 1 — TS baker tooling(working tree、新規ファイル)

**新規 5 ファイル**:
- `packages/film-lab-core/src/bake-color-only.ts` — Stage 2 (baseGrade) / 3 (filmCompression) / 9 (printStage) の 12 color ops を float64 で実装。`apps/.../FilmtoneExportSidecarBuilder.swift:645-714` の `applyBaseGrade` / `applyFilmCompression` / `applyPrintStage` を **1:1 ポート**(SSOT 契約)
- `packages/film-lab-core/src/creative-cube.ts` — 33³ R-fastest grid walker、`makeCreativeCube({params, size})` / `makeIdentityCube()` / `diagonalMaxDelta()`
- `packages/film-lab-core/src/creative-cube-serialize.ts` — Adobe `.cube` text serializer。round-trip with `cube-parser.ts` byte-identical(modulo float text precision)
- `packages/film-lab-core/src/creative-pack-01.ts` — 4 Look definition struct + `buildLookParamOverrides({})` helper(spatial 入力に 12 color op neutralization をマージ)
- `packages/film-lab-core/src/bake-color-only.test.ts` + `creative-cube.test.ts` — 25 tests(全 green)

**Orchestrator(新規)**:
- `scripts/build-creative-luts.ts` — 3 mode (`--regenerate` / `--regenerate-identity` / `--verify`)。manifest 出力と sha256 pin discipline。

**`packages/film-lab-core/src/index.ts`**:
- 上記の新 module re-export 追加

### 2.3 Phase 2 — Swift catalog & binding 拡張

**`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySchema.swift`**:
- `CreativeLutBinding` enum に `case bundled(slug, filename, sha256, intensity)` 追加(従来 `.libraryRef` / `.embedded` の 2 case → 3 case)
- `Kind` enum に `.bundled`、`init(from:)` / `encode(to:)` / `intensity` switch / `libraryId` 更新
- `var bundledSlug: String?` accessor 追加

**`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift`**:
- `BuiltInLook` struct に `let packId: String?` 追加
- `static let creativePack01Id = "creative-pack-01"`
- `allLooks` 構成変更(後述 §3.1):
  - **削除**: Filmtone Signature / Clean Base / Amber Glow / Soft Blue(degenerate preset wrappers)
  - **保持**: Night Soft(curated softBlue variant)
  - **新規**: Pack 01 × 4(Tungsten Bloom / Window Diffusion / Vintage Haze / Golden Halation)
- `BuiltInLookUUID` enum:
  - `...000001` – `...000004` を deprecated コメントとして永久 leak(再利用禁止)
  - `nightSoft = ...000005`(active)
  - `creativePack01TungstenBloom = ...000006` / `creativePack01WindowDiffusion = ...000007` / `creativePack01VintageHaze = ...000008` / `creativePack01GoldenHalation = ...000009`
- 4 個の `creativePack01<Look>Patch` static 定数(per-Look `FilmtonePhase0ParamsPatch`、12 color op neutralization + lens-filter spatial overrides)

**`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift`**:
- `ParsedCubeLutDTO` / `SerializableLutDTO` に optional `bundledSlug: String?` / `bundledPackId: String?`(decode-with-default、Codable backward-compat)

**`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`**:
- `import CryptoKit` 追加
- `applySavedLook` の switch に `.bundled` arm 追加
- `static func loadBundledCreativeLut(slug, filename, pinnedSha256, intensity, packId) -> ParsedCubeLutDTO?` ヘルパ
  - `Bundle.main.url(forResource:, subdirectory: "CreativeLuts")` で resolve
  - `SHA256.hash(data:)` で **file-text bytes** に対する hash 検証(orchestrator が出した sha256 と一致確認)
  - mismatch / not-found → nil 返却 → caller が `lutMissingForApply` toast(silent degrade なし、`feedback_no_fallback_bug_hotbed`)

**`apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift`**:
- `transportLut` で bundled 情報 `SerializableLutDTO` まで thread-through

**`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`**:
- `SidecarLutRef` に optional `bundledSlug` / `bundledPackId`(`encodeIfPresent`、V1 schema 互換)
- `resolveCreativeLutRef` で creativeLut / legacy lut DTO から拾って copy

**`apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift`**:
- contract test stub の `ParsedCubeLutDTO` / `SerializableLutDTO` ミラー同期(本体と同じ optional fields)

### 2.4 Phase 3 — i18n

**`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`**:
- 4 stored property: `builtInLookCreativePack01TungstenBloom` / `WindowDiffusion` / `VintageHaze` / `GoldenHalation`
- `builtInLookName(for slug:)` switch 4 case 追加(slug → localized 名)
- `filmtoneLocalized(...)` 4 initializer(ja/en defaultValue:)
- v1.3 削除に伴い:
  - `builtInLookFilmtoneSignature` / `CleanBase` / `AmberGlow` / `SoftBlue` 削除
  - `builtInBadgeLabel` 削除(後述 §2.6)
- v1.3 builtin_look pattern を踏襲し **xcstrings 登録なし**(defaultValue ja/en branch のみ)

### 2.5 Phase 4 — pbxproj 4-section folder reference

**`apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`** に `Resources/CreativeLuts` を folder reference (青フォルダ)で登録:
- `D40000010000000000000001` /* CreativeLuts */ — PBXFileReference (`lastKnownFileType = folder; path = "Resources/CreativeLuts"`)
- `D40000010000000000000002` /* CreativeLuts in Resources */ — PBXBuildFile
- App group `children` に追加(public 隣接)
- App target の `PBXResourcesBuildPhase.files` に追加

→ 4 section grep 確認済(`grep -c CreativeLuts ... = 4`)。folder reference なので Pack 02 への拡張・cube 追加で pbxproj 再編集不要。

### 2.6 UI 改善(2026-05-01 後半 user feedback 反映)

**FILMTONE バッジ削除**(plan には無い、screenshot 経由のフィードバック):
- 旧: チップ右上に "FILMTONE" caption pill が overlay → ja chip 名と被って読めない
- 修正: `FilmtoneLibrarySection.swift` の `.overlay(alignment: .topTrailing)` ブロックを削除、`FilmtoneLibraryChip.badgeText: String?` パラメータを `isBundled: Bool` に変更
- 視覚的 bundled 識別は **amber 背景チント (0.18) + amber stroke (0.32)** だけで十分
- `FilmtoneStrings.builtInBadgeLabel` 削除(unused になったため)

**v1.3 degenerate Look 削除**(CD 指摘):
- 旧 5 entries の内 4 個(Filmtone Signature / Clean Base / Amber Glow / Soft Blue)が `paramOverrides == .empty` + `quickState == .zero` + `creativeLut == nil` で **preset 直接タップと byte-identical** → Look 抽象を意味を持たなくする
- Night Soft だけ genuine(softBlue + 12 値 paramOverrides)
- 削除後の chip strip = 5 entries(Night Soft + Pack 01 × 4)
- 互換性: built-in favorites は UserDefaults `filmtone.builtinLookFavorites` に slug キーで保存 / SavedLookEntry JSON は materialize 時生成・persistence なし → UUID downgrade-safe by construction

**Look 名称改善**(CD 指摘 "意味不明"):
- Warm Print → **Tungsten Bloom** / タングステンブルーム
- Cold Steel → **Window Diffusion** / 窓辺ディフュージョン
- Faded Document → **Vintage Haze** / ヴィンテージヘイズ
- Sunbeam → **Golden Halation** / ゴールデンハレーション
- 命名軸 = **シーン/ムード** + **Filmtone レンズフィルター signature**(bloom / diffusion / soft+grain+vignette / halation)
- slug もファイル名と整合させて改名(`filmtone-creative-pack-01-tungsten-bloom.cube` 等)

**per-Look spatial overrides**(CD 指摘 "Filmtone 独自性を強調"):
- 現状: cube は color 担当、basePreset の spatial 値は素のまま
- 修正後: 各 Look の `paramOverrides` に lens-filter spatial 値を追加 → basePreset から **個別の光学性格** を出す
- 配置: TS `creative-pack-01.ts` に `paramOverrides: buildLookParamOverrides({...spatial...})`、Swift `FilmtoneBuiltInCatalog` に per-Look `creativePack01<Look>Patch` static
- TS / Swift の spatial 値は手動 sync(future: scripts/build-creative-luts に sync gate 追加余地)

### 2.7 cube 再 bake & sha256 pin 同期
- `bun run scripts/build-creative-luts.ts --regenerate` で 4 cube + manifest 出力
- 旧 slug の cube 4 ファイル削除 (`rm filmtone-creative-pack-01-{warm-print,cold-steel,faded-document,sunbeam}.cube`)
- Swift `FilmtoneBuiltInCatalog` の sha256 4 件を新値に同期
- `--verify` で再 bake bytes が一致することを確認(byte-pin discipline)

### 2.8 Verification 通過した gate
- `bun run build:core`: ✓
- `bun test packages/film-lab-core/`: 146 pass / 2 fail(※ 2 fail は user の **別 in-progress** な `presets.ts` haloPrism 追加 drift。私の LUT 変更とは無関係 — 後述 §6.1)
- `bun run typecheck:shared`: ✓
- `bun run verify:ios`(motion blur / cube parser / source profile / sidecar): ✓
- `bun run scripts/build-creative-luts.ts --verify`: ✓ 4 cubes mode=real packId=creative-pack-01
- `xcodebuild -workspace ... -scheme App -destination 'generic/platform=iOS Simulator' clean build CODE_SIGNING_ALLOWED=NO`: ✓ **BUILD SUCCEEDED**(2 回確認)
- pbxproj 4-section grep: ✓ 4 occurrences
- 実機 build (千葉工の iPhone): ✓(DerivedData / xcuserdata deep reset 後に通過)

### 2.9 Xcode IDE 状態リセット(stale cache 対策)
実機 build で初回 "Cannot find 'FilmtoneHelpAssetGenerator' in scope" エラーが出た。原因は Xcode の workspace cache が pbxproj 外部編集を完全 reload しきれていなかった。下記 deep reset で解消:

```sh
rm -rf ~/Library/Developer/Xcode/DerivedData/App-*           # 29 件削除
rm -rf .../App.xcworkspace/xcuserdata
rm -rf .../App.xcodeproj/xcuserdata
xcodebuild ... clean build                                    # ✓ BUILD SUCCEEDED
open .../App.xcworkspace                                       # 完全 fresh state で再 open
```

---

## 3. 現在の catalog state

### 3.1 chip strip(5 entries)

| # | Look | basePreset | UUID | creativeLut | paramOverrides 性格 | sha256(file-text) |
|---|------|-----------|------|-------------|---------------------|---|
| 1 | Night Soft(v1.3 carry-over)| softBlue | `FB1A...000005` | nil | warm intimate candlelight 12 値 override | n/a |
| 2 | Tungsten Bloom | iphone | `FB1A...000006` | bundled | bloom-led: bloomThreshold 0.58 / Strength 0.32 / Radius 0.62 + halation 0.18 / diffusion 0.08 | `fafe80f6118f71b8954e4a943e7fa8ae0d85ceecfac4b0c0c49e7109a16c612c` |
| 3 | Window Diffusion | softBlue | `FB1A...000007` | bundled | diffusion-led: diffusion 0.20 / bloomThreshold 0.50 / Strength 0.32 / lensSoftness 0.30 + halation 0.10 hue 14 | `a8d7c02def4cd227c3795ba4859679d9f373b026107e51b371b9d5971be288f0` |
| 4 | Vintage Haze | iphone | `FB1A...000008` | bundled | soft-lens-grain-led: lensSoftness 0.32 / grainSize 0.42 / grainIntensity 0.028 / vignette 0.32 + halation 抑制 0.04 / bloomStrength 抑制 0.10 / diffusion 0.18 | `ef399f50e7b852fb97903c71ee2c27d35841774a7417e2a761a14c5d08588d77` |
| 5 | Golden Halation | amberGlow | `FB1A...000009` | bundled | halation-led max: halationIntensity 0.32 / Radius 0.55 / Hue 38 + bloomThreshold 0.50 / Strength 0.34 + diffusion 0.16 | `e072292d94533f9a91ccc114f0c9566ff7f53d72fb90bbefbccf33a46a089d3d` |

### 3.2 Pack 01 cube colorParams(現状の baked 値、TS `creative-pack-01.ts` 参照)

| op | Tungsten Bloom | Window Diffusion | Vintage Haze | Golden Halation |
|---|---:|---:|---:|---:|
| exposure | 0 | 0 | 0.06 | 0 |
| contrast | 1.10 | 1.22 | 0.85 | 1.15 |
| saturation | 0.95 | 0.82 | 0.70 | 1.18 |
| temperature | 0.18 | -0.22 | 0.10 | 0.30 |
| tint | 0.02 | -0.04 | -0.02 | 0.04 |
| fade | 0.04 | 0.06 | 0.18 | 0.04 |
| compressionAmount | 0.50 | 0.42 | 0.30 | 0.55 |
| compressionRange | 0.55 | 0.5 | 0.5 | 0.55 |
| printContrast | 0.20 | 0.15 | 0.06 | 0.25 |
| cyan | -0.06 | 0.18 | -0.05 | -0.14 |
| magenta | 0.05 | -0.06 | 0.02 | 0.20 |
| yellow | -0.10 | -0.08 | 0.12 | 0.15 |

**diagonal max delta**(neutral 軸からの最大乖離、RGB unity diagonal):
- Tungsten Bloom: 0.151
- Window Diffusion: ~0.18 (manifest 参照)
- Vintage Haze: ~0.20
- Golden Halation: ~0.18

→ どの Look も R=G=B 軸でグレー保持できておらず、明確な color shift が出る(意図通りだが大きすぎる可能性 — §4 参照)。

---

## 4. 残課題:CD フィードバック「クオリティが低い、破綻も見られる」

### 4.1 フィードバック原文(2026-05-01 実機確認後)
> "ビルド確認はできましたがやはりクオリティが低い上に破綻も見られる"

### 4.2 推定原因(次 chat で要 deep dive)

私(直前 chat の AI)が baked した colorParams は **CD 視点なしの first-pass educated guess**。Palermo design 哲学 + Pack 01 character description から逆算したが、CD reference frame での視覚検証はゼロ。具体的に疑われる破綻ポイント:

1. **highlights 飛び**: `compressionAmount 0.50-0.55` + `temperature 0.18-0.30` の組み合わせで暖色 highlight が clip。特に Tungsten Bloom / Golden Halation
2. **shadow color 溢れ**: `cyan -0.06 to -0.14` を print stage で全 RGB 軸に subtract している → 暗部で R チャンネルが意図せず lift
3. **saturation 破綻**: Vintage Haze の `saturation 0.70` + `fade 0.18` で skin tone が完全に死ぬ
4. **double-bloom 重複疑念**: paramOverrides で bloomStrength 0.32 を加え、basePreset (iphone) も内部で bloom 計算 → 二重 bloom で highlight が爆発する可能性
5. **halation 破綻**: Golden Halation の `halationIntensity 0.32` は amberGlow baseline 0.16 の 2 倍 — 視覚的に "halo" が "光線病" になっているかも
6. **lens character 自己矛盾**: Vintage Haze は `halationIntensity: 0.04`(抑制)を意図したが、basePreset の iphone が halation 0.10 で **paramOverrides は base に上書きする** ので、結果は 0.04 になっているはず — これは正解。ただし bloomStrength 0.10 にしているのに basePreset bloomStrength 0.18 を上書きするだけ → 期待通り。**だが** runtime kernel の non-double-apply 契約を再確認すべき
7. **non-double-apply 契約の正当性**: paramOverrides で 12 color op を neutral に pin しているが、本当に runtime kernel がそうなっているか? `applySavedLook` → `state.paramOverrides = entry.paramOverrides` → `recomputeProjectParams()` で `resolveParams(presetName, strength, quickState, paramOverrides)` を呼ぶ。`paramOverrides` は preset 上に上書き → 正解のはず。**ただし** Stage 9 (printStage) は cube 適用「後」に runtime 走るので、paramOverrides で `cyan/magenta/yellow/printContrast = 0` に pin されていれば Stage 9 は no-op になる、これは仕様通り
8. **saturation 0.70 の Vintage Haze**: cube 内で sat=0.70 baked → applied as-is by Core Image trilinear → さらに preset の saturation neutral (1.0) ↑ runtime では当てない → CD の "破綻" がここに集中している可能性

### 4.3 実装の **非破綻** 部分(次 chat で触らないでよい部分)

- Configuration / wiring(Phase 0-2 のすべて、SHA-256 verify、sidecar provenance、folder reference)
- TS baker math(`bake-color-only.ts` は Swift `applyBaseGrade/applyFilmCompression/applyPrintStage` の 1:1 ポート、SSOT 契約で **動かない**)
- 4 entry 削除 + 4 名称改善 + バッジ削除(これらは UI / IA decision で完了)
- per-Look spatial overrides の **構造**(=値 ではなく "Look ごとに spatial を override する仕組み")
- `loadBundledCreativeLut` の sha256 fail-closed 実装

→ **次 chat で触る範囲 = colorParams 12 値 + spatial override 値 のみ**(構造的決定は終わっている)

---

## 5. ファイル別 final state(diff stat 視点)

```
working tree (uncommitted):
 M apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj         # +4 lines (CreativeLuts folder ref)
 M apps/capacitor-film-lab-ios/ios/App/App/AppDelegate.swift                  # 既存(user 別作業, FilmtoneHelpAssetGenerator 呼び出し)
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift       # ~150 行(削除+追加+per-Look patch)
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift          # +60 行 (.bundled arm + loadBundledCreativeLut)
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift # SidecarLutRef 拡張 + resolveCreativeLutRef
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySchema.swift        # CreativeLutBinding .bundled case
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneLibrarySection.swift       # FILMTONE バッジ削除
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift           # ParsedCubeLutDTO/SerializableLutDTO 拡張
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift           # transportLut thread-through
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift        # 既存(user 別作業)
 M apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift              # built-in look strings
 M apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift    # contract DTO mirror
 M messages/en.json / messages/ja.json                                         # 既存(user 別作業)
 M packages/film-lab-core/dist/index.d.ts / index.js                          # build artifact
 M packages/film-lab-core/src/index.ts                                         # 新 module re-export
 M packages/film-lab-core/src/optical-recommendation.* / params.ts / presets.ts / schema.ts
                                                                              # 既存(user 別作業 — haloPrism)
 M packages/film-lab-renderer/src/webgpu/* + dist/                             # 既存(user 別作業)
 M packages/film-lab-ui/src/FilmLabControlPanelCore.tsx                        # 既存(user 別作業)
?? apps/capacitor-film-lab-ios/ios/App/App/Resources/                          # NEW (4 cube files)
?? apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/                # NEW (manifest.json)
?? packages/film-lab-core/src/bake-color-only.ts                               # NEW
?? packages/film-lab-core/src/bake-color-only.test.ts                          # NEW
?? packages/film-lab-core/src/creative-cube.ts                                 # NEW
?? packages/film-lab-core/src/creative-cube.test.ts                            # NEW
?? packages/film-lab-core/src/creative-cube-serialize.ts                       # NEW
?? packages/film-lab-core/src/creative-pack-01.ts                              # NEW
?? scripts/build-creative-luts.ts                                              # NEW

committed:
- 9d735ff "feat(ios): finalize preset default and LUT provenance"  ← Phase 0 schema additive のみ
```

git operations は user が手動。自動 commit/push 禁止(CLAUDE.md §11)。

---

## 6. 既知の orthogonal な drift / 未解決事項

### 6.1 `presets.ts` haloPrism contract drift(user 別作業)
- `packages/film-lab-core/src/presets.ts` で `ContractDefaultKey` union に 8 keys (`haloPrismStrength` / `Radius` / `Width` / `Chromatic` / `Threshold` / `Split` / `Angle` / `SourceReactivity`) が追加されている
- しかし `packages/film-lab-core/src/ios-swift-payload.ts` の `CONTRACT_DEFAULT_KEY_ORDER` が同期していない
- → `bun test packages/film-lab-core/src/ios-swift-payload.test.ts` で 2 fail(`hiddenDefaults length` + `KEY_ORDER`)
- これは user の別 lane の in-progress work、私の LUT 変更と無関係。修正は user の judgement
- 再現:`bun test packages/film-lab-core/src/ios-swift-payload.test.ts`

### 6.2 contract test stub の duplicate fields
- `apps/capacitor-film-lab-ios/scripts/swift/phase0-contract-support.swift` は production DTO の **subset mirror**。Phase 2 PR で `ParsedCubeLutDTO` / `SerializableLutDTO` 拡張に追従済
- もし将来 `Phase0ParamsDTO` 等を変えたら contract stub も更新が必要(verify-phase0-contract.sh が gate)

### 6.3 marketing site / portfolio 側の追従が未完
- 削除した v1.3 4 entries(Filmtone Signature 等)が `messages/en.json:1612` 周辺と portfolio repo の landing copy に登場する可能性
- ASC submitted v1.3 が公開済の場合、screenshot / metadata に旧名称が残る — life の `scripts/check-filmtone-release-truth.sh` で要確認
- 修正タイミング:Pack 01 contents が CD signoff された後(本 doc の続きで対応)

### 6.4 Tier 1/2/3/4 fixture の未生成
- 直前 plan の §Phase 6 で manifest skeleton までは作ったが Tier 1 fixture(Python ramp)/ Tier 2 (Halton random) / Tier 3 (Macbeth) / Tier 4 (DaVinci visual diff) は **未生成**
- Pack 01 の colorParams が CD 確定後に生成すべき。各 Look × 3 fixture = 12 fixture
- 場所: `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/<slug>/{encode-ramp.py, grayscale-ramp.json, grid-samples.json, macbeth-patches.json, provenance.md}`

### 6.5 UI section header "Creative Pack 01" 未実装
- 直前 plan の §verification §9 では "v1.4 entry は 'Creative Pack 01' section header 下にグルーピング" を要求
- 現状: chip strip 末尾に追加されただけ、section divider なし
- 将来 UI 拡張余地。Pack 02 が出るタイミングで section 化検討

---

## 7. 検証コマンド集(次 chat 即実行可能)

```sh
# 場所: /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

# ① TS baker rebuild + test
bun run build:core
bun test packages/film-lab-core/src/bake-color-only.test.ts packages/film-lab-core/src/creative-cube.test.ts

# ② cube 再 bake(colorParams / spatial 編集後)
bun run scripts/build-creative-luts.ts --regenerate
# 出力: 4 cube + manifest.json

# ③ pin discipline 検証(commit 前 mandatory)
bun run scripts/build-creative-luts.ts --verify
# expects: "verify OK — 4 cubes, mode=real, packId=creative-pack-01"

# ④ sha256 sync to Swift catalog
grep -E "slug|cubeSha256" apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json
# → 出力 4 sha256 を FilmtoneBuiltInCatalog.swift の各 .bundled(sha256:) に手動コピー

# ⑤ ios contract test stubs
bun run typecheck:shared

# ⑥ ios verify suite
bun run verify:ios   # ※ 内部で cap sync。Bundler 失敗時は PATH=/opt/homebrew/opt/ruby/bin:$PATH を export

# ⑦ Simulator build(全変更後の sanity)
cd apps/capacitor-film-lab-ios && \
  xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug build CODE_SIGNING_ALLOWED=NO

# ⑧ pbxproj invariant
grep -c CreativeLuts apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj
# expects: 4

# ⑨ 実機 build 前の Xcode リセット(stale cache 出たら)
rm -rf ~/Library/Developer/Xcode/DerivedData/App-*
rm -rf apps/capacitor-film-lab-ios/ios/App/App.xcworkspace/xcuserdata
rm -rf apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/xcuserdata

# ⑩ Xcode 再 open(life の open:ios script は `bun run open:ios` 経由)
open apps/capacitor-film-lab-ios/ios/App/App.xcworkspace
```

---

## 8. 最重要の不変条件(次 chat が壊してはいけない)

| 不変条件 | 場所 | 違反症状 |
|---|---|---|
| `bake-color-only.ts` は Swift `FilmtoneExportSidecarBuilder.applyBaseGrade/FilmCompression/PrintStage` の **1:1 ポート** | `packages/film-lab-core/src/bake-color-only.ts` | TS↔Swift で生成 cube が byte-divergent → "Look→.cube export" lane の Tier 1 byte-identity が崩壊 |
| **non-double-apply 契約**: 各 Look の paramOverrides は 12 color op を neutral に pin | `creative-pack-01.ts` `buildLookParamOverrides()` + Swift `creativePack01<Look>Patch` の `creativePack01ColorOpNeutralEntries` | runtime kernel が cube + preset color 両方適用して double 強調 |
| **byte-pin discipline**: ship 後 cube 不変、改善 baker は次 pack | `bakerVersion = "1.0.0"`、`scripts/build-creative-luts.ts --verify` で CI gate | Pack 01 の意味的固定性が崩れる(同じ Look で出力が変わる) |
| **`Resources/CreativeLuts/` と `public/luts/` の分離** | folder reference + `.gitignore` 不要 | `cap sync` が `public/` のみ書き換え、`Resources/` は不変。混ぜると `cap sync` で消える |
| **canonical UUID `FB1A...000001-000004` 永久 leak** | `BuiltInLookUUID` enum コメント | 削除済 v1.3 entry の UUID を再利用すると orphan favorite で別 Look 適用される |
| **iOS preset name lock**: `reset` / `iphone` / `softBlue` / `amberGlow` のみ | `ios-preset-overrides.ts:20-25` / `apps/capacitor-film-lab-ios/CLAUDE.md` | 新 preset 名を導入すると `FilmtonePhase0Generated.swift` 再生成必要 — invariant 抵触 |
| **`FilmtonePhase0Generated.swift` 手動編集禁止** | generator: `scripts/generate-filmtone-ios-swift.ts` | drift で iOS Swift contract が壊れる |
| **`messages/{en,ja}.json` は marketing site SSOT** | iOS の display name は `Localizable.xcstrings` / `FilmtoneStrings.swift` defaultValue | 混同で iOS が web 用文字列を読む |
| **JSX comment を `return (` の直下に置かない** | TSX 全般、`feedback_no_jsx_comment_outside_root_return` | Vite build で `Expected ',', got '<elementName>'` |
| **`動画`(× `短尺動画`)/ `video`(× `short-form video`)用語ロック** | life commit `5ce6d55`(2026-05-01) | docs / UI 文言で短尺動画と書くと用語汚染 |

---

## 9. 工数見込(次 chat で本格 iteration)

| Lane | 想定作業 | 想定工数 |
|---|---|---|
| CD reference frame curation | 各 Look × 3 frame(highlight / midtone / shadow 代表)の MP4 / HEIC 選定 | 0.5d(CD 自身)|
| colorParams iteration | TS `creative-pack-01.ts` 編集 + `--regenerate` + 実機確認 × 4 Look × ~6 cycle | 1.5–2d |
| spatial override iteration | per-Look `paramOverrides` 値調整 + 実機確認 | 1d |
| 破綻 root cause 調査(double-apply 検証等) | 必要なら native kernel と TS bake の cross-check 1 frame trace | 0.5d |
| Tier 1/2/3 fixture 生成(Python + JSON) | colorParams 確定後、各 Look 3 fixture | 0.5d |
| Tier 4 (CD signoff) | 各 Look × 3 frame で in-app vs DaVinci 視覚 diff | 0.5d(CD)|
| sha256 同期 + verify | 自動化検討余地(現状手動) | 0.1d |
| **合計** | | **~4-5d**(CD と eng 並走時)|

---

## 10. 引き継ぎ先 chat への提案アクション順

次 chat の AI が取るべき順序(これに沿うと最大効率):

1. **本 doc を最初から最後まで読む**(コンテキスト全把握)
2. `git status --short` + `bun run scripts/build-creative-luts.ts --verify` で現状確認
3. `apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json` の `colorParams` を読み、各 Look の現状値把握
4. `packages/film-lab-core/src/creative-pack-01.ts` の `paramOverrides` 内 spatial values と整合確認
5. CD に **「破綻」の具体例を確認**(画像 / 動画 / 自然言語 description のいずれか) — どの Look、どのシーン、何が破綻か
6. CD reference frame があれば共有を依頼 — なければ各 Look の意図(scene + lens character 期待値)を再確認
7. `mcp__sequential-thinking__sequentialthinking` で **double-apply 疑念の論理検証** から先に着手(本当に non-double-apply 契約が成立しているか、特に Stage 9 cube 適用後 + paramOverrides で printContrast=0 / cyan=0 / yellow=0 が runtime kernel で no-op になるか)
8. colorParams iteration は **小刻み**(1 値ずつ)。`--regenerate` → sha256 を Swift に sync(手動 4 行 edit)→ Simulator build → 実機確認のサイクル
9. 妥協を避ける(`保守的ヘッジ優先しない`)— "とりあえずこの値で" は禁止、CD signoff まで 1 Look ずつ完了させる

---

## 11. 直前 chat AI の self-critique(次 chat に教訓を引き継ぐ)

- **Color science を CD 検証なしで baked した**:Pack 01 の colorParams は plan §Pack 01 内容 の character description だけから逆算した first-pass。CD reference frame での視覚検証ステップを skip した
- **double-apply 検証を十分にしなかった**:non-double-apply 契約は理論的には成立するが、runtime kernel の Stage 9 (printStage) が cube 適用後に走る順序を実際に trace していない。次 chat ではここを最初に固める
- **per-Look spatial 値も educated guess**:bloom 0.32 / halation 0.32 等の数値は basePreset の 1.5-2 倍 で適当に決めた。CD 視点での検証ゼロ
- **"配管 PR で済ませる"plan 設計が現実と合わなかった**:placeholder identity → 実機確認 → real bake で iteration の plan だったが、user は最初から実 cube + CD signoff を期待していた。Phase 1 PR と Phase 2 PR の境界が曖昧で、user に twice tested させてしまった
- **Look 名称を最初から CD に提案すべきだった**:Warm Print / Cold Steel 等の凡庸な名前で実装に走り、user に "意味不明" 指摘を受けてから rename した。1 step 余計

→ **次 chat の AI は **値を baked する前に CD に確認** する習慣を最初から持つ**こと。

---

## 12. 引き継ぎプロンプト(次 chat の頭で AI に投げる用)

下記をそのまま次 chat の最初の発話としてコピーしてください。

---

### ▼ 次 chat 用プロンプト

```
Filmtone iOS Creative LUT Pack 01 のクオリティ改善を引き継ぎます。

【重要】まず以下の引き継ぎ doc を必ず最初から最後まで読み、全文を理解してから動いてください。重要箇所(§4 残課題、§8 不変条件、§10 アクション順、§11 self-critique)はメモして失わないこと。

引き継ぎ doc:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-quality-iteration-handoff-2026-05-01-jst.md

【作業環境】
- Repo: /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone (cwd)
- パッケージマネージャ: bun(npm 禁止)
- パネル: CD = chibatakumi(私)、日本語/英語可
- Auto mode 想定で動いてもよい(ただし colorParams を baked する前に必ず CD = 私に確認)

【現状】
- 配管・サイドカー・pbxproj・slug・lens-filter override の "構造" は完成
- v1.3 degenerate 4 entries は削除済、Night Soft + Pack 01 × 4 = 5 chips
- FILMTONE バッジは削除済(amber tint で bundled 識別)
- Pack 01 cubes は real bake mode で commit 待ち、xcodebuild ✓ BUILD SUCCEEDED
- 私が実機 (千葉工の iPhone iOS 26) で確認した結果 → "クオリティが低い、破綻も見られる"
- 次 chat = color science / lens character iteration が主戦場

【最初にやってほしいこと(順番厳守)】

1. 引き継ぎ doc を全文読む。読み終わったら "全文把握完了" と一言報告
2. git status --short と bun run scripts/build-creative-luts.ts --verify で現状確認
3. doc §4.2 に列挙された "破綻推定原因" 8 項目を sequential-thinking で吟味
   特に #7 (non-double-apply 契約の正当性) を runtime kernel trace で検証
4. CD (= 私) に「どの Look の何が破綻か」具体的に尋ねる
   - 可能なら CD が screenshot or 自然言語 description を提供
   - 私からの提供が無ければ "推定原因" の上位 1-2 個を仮説として提示
5. 仮説検証 → 修正案策定 → CD 承認 → 実装(colorParams or spatial override 1 値ずつ)→ --regenerate → Swift sha256 sync → Simulator build → 実機確認
6. 1 Look ずつ完了させる(妥協・並列で半端な状態を作らない)

【絶対ルール】
- doc §8 の不変条件を一つも壊さない(特に bake-color-only.ts SSOT 契約と byte-pin discipline)
- 値を baked する前に必ず CD = 私に確認(直前 chat の最大の reflection)
- "保守的ヘッジ優先しない"(life CLAUDE.md §運用原則)、品質に妥協しない
- "本質優先 / 外殻最小"。色 / spatial / 破綻調査が本質、新 UI 機能 / 装飾 banner は外殻
- 思考が必要な判断は mcp__sequential-thinking__sequentialthinking を使う(記憶ベース断言禁止)
- 不確かなら gemini-search → WebSearch で確認(`feedback_verify_before_documenting`)
- handoff doc の記述を引用する前に live state (grep / Swift / pbxproj) と突き合わせる(`feedback_verify_before_quoting_handoff`)
- Git 操作は user が行う(自動 commit / push 禁止)

【最初の発話で出力してほしい形式】
1. "引き継ぎ doc 全文把握完了"
2. git status --short と --verify の出力サマリ(2-3 行)
3. doc §4.2 #7 (non-double-apply 契約) について sequential-thinking 結果(成立 / 不成立 / 要 trace)
4. CD への質問:破綻の具体例(Look、シーン、視覚現象)を提供できるか?
   提供できない場合は推定原因 #1-#3(highlight 飛び / shadow color 溢れ / saturation 破綻)から優先順位仮説提示
5. 次の 1 アクション提案

破綻調査は私の reference frame 共有を待ってからでも良いし、推定 root cause から先行調査でも良い。あなたの judgement で決めてください。
```

---

### 受け渡し

doc 出力先: `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/creative-lut-pack-01-quality-iteration-handoff-2026-05-01-jst.md`(本ファイル)

このファイルを次 chat の AI に必ず最初に読ませること。プロンプト本文だけだと前提が抜ける。
