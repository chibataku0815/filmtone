# M5-J3 Slider Visual Polish v2

Milestone: M5 Native Editing UI (visual smoke fix)
Worktree: `filmtone-native-desktop-m5-j3-slider-polish-v2`
Branch: `feature/native-desktop-m5-j3-slider-polish-v2`
Base: `ca9acea6` (post M5-I integration close)
Date opened: 2026-05-05 JST

## Context

Right rail 上に縦に 4-5 スタックされる `FilmtoneGlassSlider` (Quick × 3 + Strength + JPEG quality + scrub bar + AdvancedAdjustEditor の N rows) で、現状の knob 32pt / pure-white fill が「丸が大きすぎる、無駄に多い、洗練されていない」と user smoke で指摘された。component を 1 file 内で微調整する。

旧 `filmtone-native-desktop-m5-j3-slider-polish` worktree は base `b3703991` でフォークしておりズレる、cherry-pick / merge は禁止。call site は既に 5 個すべて `range:` keyword で組み立て済み (M5-I.3 で `FilmtoneGlassSlider` 化済) なので、API surface (`range:` / `step:` / `onEditingChanged:`) は維持する。

## Goal

`FilmtoneGlassSlider` の視覚と挙動だけを Apple Liquid Glass の dark-tint glass posture に整える。call site には触れない。glass button / menu polish (`FilmtoneGlassMenuTrigger` / 4 ButtonStyle) と cursor helper は壊さない。

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneGlassControls.swift`
  - `FilmtoneGlassSlider` struct のみ。

呼び出し側 (`GradeControls.swift` / `QuickAdjustControls.swift` / `AdvancedAdjustEditor.swift` / `ExportInspectorPanel.swift` / `RootWindowView.swift` の VideoScrubBar) は変更しない。pbxproj / docs / verify ソースも変更不要。

## Read-Only References

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift:271-279`
  VideoScrubBar の `FilmtoneGlassSlider(value:, in:..., onEditingChanged:)` callsite (range は `0...max(duration, 0.001)`、`onEditingChanged` で `state.stopPlayback()`)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift:97`
  Quick の 3 axis slider callsite (`range:` + `step:`)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/GradeControls.swift:35`
  Strength slider callsite (`range: 0...1`)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustEditor.swift:205`
  Advanced editor の 30+ field 行ごとの callsite

## Visual / Behavior Spec

- knob: base **14pt**、hover/drag **18pt**、`.easeOut(0.12)` で scale (初期 18/22 で smoke、user 指摘で 14/18 に縮小確定)。
- track: **4pt** 厚 (初期 5pt → smoke で 4pt 確定)。
- 未選択 track: `Color.white.opacity(~0.12)` (low contrast)。
- filled track: pure white ではなく glass highlight 程度 (`Color.white.opacity(~0.45)`)。
- knob: `Color.white.opacity(~0.92)` + 0.5pt 微 stroke + 軽い影 (元の重い shadow は廃止)。
- disabled: `@Environment(\.isEnabled)` で fill / shadow を dim、行全体は `.opacity(0.55)`。
- knob 半径補償: `(locationX - knob/2) / usable` で edge-of-track 精度を維持 (現行は `locationX / width`)。
- 行高: 24pt 固定 (knob 18→22 pulse が layout を揺らさないため、knob の `.frame(height:)` ではなく外側 `.frame(height: 24)` で抑える)。
- hover: `.onHover` で isHovering = hovering && isEnabled。
- cursor: 既存 `.filmtonePointingHandCursor()` 維持。
- drag cleanup: `onChanged` で `guard isEnabled else { return }`、`onEnded` の cleanup は `isEnabled` ガードしない (drag 中 disabled flip で latch しないため)。`updateValue` の呼び出しのみ isEnabled gate。
- `onChange(of: isEnabled)`: drag 中に disabled flip → 即時 `isDragging = false` + `onEditingChanged?(false)` + `isHovering = false`。
- `onDisappear`: drag 中なら cleanup (現行と同等)。
- API: `range:` / `step:` / `onEditingChanged:` を一切変えない。

## Non-Goals (explicit out of scope)

- J1 の sidebar layout には触れない。
- J2 の compare には触れない。
- 呼び出し側 (5 ファイル) の signature / stacking / spacing は触れない。
- `FilmtoneGlassMenuTrigger` / 4 ButtonStyle / `filmtonePointingHandCursor` は触れない。
- pbxproj / Verify SOURCES に変更なし。

## Checklist

- [x] `FilmtoneGlassSlider` struct を在地置換 (in-place 改修)。
- [x] `git diff` で当該 1 file 1 struct のみが変わっていることを確認 (1 file changed, +57 / -24)。
- [x] 5 call site を grep し signature mismatch なしを確認 (range: keyword 5/5 維持)。
- [x] `bash apps/filmtone-desktop-macos/Verify/run.sh` → 65/65 PASS。
- [x] `bun run verify:macos` → `** BUILD SUCCEEDED **`。
- [x] `git diff --check` clean。
- [x] active.md を archive へ移動。
- [x] `strategy.md` Completion Log に 1-3 行追記。
- [x] commit。push しない。

## Verification Run (2026-05-05)

- `git diff --check` → clean。
- `Verify/run.sh` → `65/65 passed, 0 failed`。
- `bun run verify:macos` → `** BUILD SUCCEEDED **`。

## Verification

- `git diff --check apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneGlassControls.swift` clean
- `Verify/run.sh` 全テスト PASS (現行 65/65)
- `bun run verify:macos` `** BUILD SUCCEEDED **`

## Done Conditions

- knob 14pt / 18pt hover-drag scale + 4pt track + low-contrast unfilled + glass highlight filled が実装済 (user 視覚 smoke 後に 18/22/5 → 14/18/4 へ縮小確定)。
- API (`range:` / `step:` / `onEditingChanged:`) と cursor / onDisappear / onEnded cleanup が温存。
- Verify + xcodebuild Debug + diff check の 3 gate pass。
- Archive 済 + strategy completion log 更新済 + 1 commit。

## Stop Conditions

- Verify 失敗が 3 連続で同根因 → 停止して報告。
- 呼び出し側 5 file の signature 変更が必要になった → 停止して報告 (scope 逸脱)。
- glass button / menu polish 側の API を変えないと polish が成立しない → 停止して報告。

## Unexpected / Follow-up

(none yet)
