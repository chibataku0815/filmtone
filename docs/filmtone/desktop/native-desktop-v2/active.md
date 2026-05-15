# Active — Black Point + Toe Contrast 黒の床 / 黒の硬さ 2 key 追加 (iOS + macOS)

Inserted 2026-05-15 JST as a short interrupt against the Twilight bundled
Look lane (paused — see `paused/2026-05-15-twilight-bundled-look.md`).

## Goal

Filmtone の baseGradeV2 grade pipeline に **黒浮き** 制御の 2 key を追加する:

- `blackPoint` (Double, range `-1..+1`, default 0) — 黒の床位置。正で milky lift、負で Baselight Flare 型 `x²(1+f)/(x+f)` の深黒沈み込み。
- `toeContrast` (Double, range `0..1`, default 0) — 黒 anchor 近傍 (0..0.15) の局所 power-curve。0 を anchor 保持で「黒の硬さ」を増やす。

iOS + macOS 同時着地。preset 値は全 11 preset = `0, 0` で plumbing landing のみ。preset aesthetic tuning は別 lane。

## Why this dial is missing today

- `fade` は white 加算で正方向のみ、黒を**沈める**方向にダイヤルが回せない
- `shadowLatitude` は midtone separation、`compressionAmount` は意図的に shadows 保護、`printContrast` は global S-curve
- 結果として深黒ルック (cinematic / bleach bypass / 高 contrast neg-print) は preset hardcode 依存 → user が dial で作れない

業界調査: DaVinci Lift / Lightroom Blacks / **Baselight Base Grade Flare** (`y = x²(1+f)/(x+f)`、0 を smooth に anchor、x=1 不変、負値リスクなし) / Dehancer Print Density。実装は Lightroom 互換の命名で Baselight 級の数式品質を採用。

## Edit Targets

- `packages/film-lab-core/src/`: params, phase0-schema, schema, presets, creative-pack-01, bake-color-only, 4 tests
- `packages/film-lab-swift-core/`: FilmtonePhase0Params + 2 tests
- `apps/capacitor-film-lab-ios/`: kernel / pipeline / DTO / OpticsCompositor / sidecar / UI / strings / contract scripts / fixtures
- `apps/filmtone-desktop-macos/`: kernel / pipeline / preset lerp / creative-pack catalog / sidecar / advanced adjust / strings / Verify

詳細リストは `/Users/chibatakumi/.claude/plans/worktree-recursive-badger.md` の「触るファイル一覧」(~30 files) を参照。

## Read-Only References

- 業界調査と数式設計: 計画ファイル本文
- `docs/filmtone/filmtone-copy-quality-harness.md` — UI string 文言 4 件追加時の guardrail
- `apps/capacitor-film-lab-ios/CLAUDE.md` — pbxproj 4-section / Profile / Sidecar 不変条件
- `paused/2026-05-15-twilight-bundled-look.md` — Twilight lane 復帰時の context

## Done Conditions

1. `bun run --cwd packages/film-lab-core test` green（既存 schema/payload テストが新 field を自動拾い + 明示 range/default test pass）
2. `bun run generate:ios-swift --check` drift なし
3. `swift test --package-path packages/film-lab-swift-core` green
4. `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract` green
5. `bun run --cwd apps/capacitor-film-lab-ios verify:baseGrade-v2` green
6. `bun run verify:macos` green（CoreCatalogStoreStringTests の 32→34 controls 反映済み）
7. `bun run verify:ios` green
8. `bun run check:filmtone-context` green
9. macOS / iOS Xcode で `blackPoint=±1` / `toeContrast=1` を回して視覚動作確認

## Verify Plan

Step 6 終了時に上記 9 件を順次実行。途中で 1 件でも fail したら原因解決まで commit しない。視覚確認は user の最終判断。

## Copy / History Impact

UI string labels only — 「Black Point / 黒レベル」「Toe Contrast / 黒の硬さ」の 4 文字列追加（macOS + iOS）。release notes / blog / changelog は本 lane では作らない。

## Article Opportunity

Short post または Developer note 候補: 「黒の床」「fade と blackPoint の役割分担」「Baselight Flare の数式」。draft は本 lane では作らない、land 後に engaging-writing skill で。

## Out of Scope

- preset aesthetic tuning（cinematic / bw / portra 等の preset 値変更）
- `FilmtoneExportSidecarBuilder.applyBaseGrade` の full baseGradeV2 parity 化
- v1 kernel path への新 param 反映
- Look catalog の **paramOverrides** / canonicalUUID / strength / sourceCubeTransform 変更（neutralization の `colorParams` のみ touch）
- portfolio submodule bump（user 実行）
- commit / push（CLAUDE.md §9 通り user 実行）

## Done

完了時は archive へ移動し、`strategy.md` に 1-3 行追記。Twilight Look lane (`paused/2026-05-15-twilight-bundled-look.md`) を active へ復帰させる。
