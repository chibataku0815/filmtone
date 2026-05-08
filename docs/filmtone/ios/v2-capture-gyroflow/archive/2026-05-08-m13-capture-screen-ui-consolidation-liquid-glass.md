# Active: M13 — Capture Screen UI Consolidation + Liquid Glass

Date: 2026-05-08 JST
Branch: `worktree-feature+ios-m9-recording-export-completion`
Status: **superseded — functional owner walk PASS, product experience rejected; M13-I active opened**

## Why this active exists

M10〜M12 made the capture surface powerful: live Look preview, Look selection,
lens switching, SSD / proxy routing, EV bias, tap focus / meter, WB lock, and
manual ISO / shutter.

The product problem is now UI priority. The capture screen can do the right
things, but the owner should not need to parse a dense control stack while
shooting. M13 makes the screen feel like a camera: preview first, record
obvious, common controls close, advanced controls available but secondary.

Liquid Glass is used to improve legibility and hierarchy over live video, not
as decoration.

## Product Rule

- Live preview is content. Liquid Glass belongs to floating controls only.
- Record / Stop is the strongest control.
- Look, lens, storage, and duration are normal capture controls.
- EV / WB / ISO / shutter / focus / meter are Advanced controls and collapsed
  by default.
- Manual active state must remain visible even when Advanced is collapsed.
- No master writer, proxy, capture package, Look preview, lens, or manual
  behavior changes in this lane.
- No React/Capacitor changes.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureChrome.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureLookModel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureTopStatusBar.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureBottomDeck.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureAdvancedDrawer.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureInteractionOverlay.swift`
- `docs/filmtone/ios/v2-capture-gyroflow/active.md`

## Read-Only References

- `docs/filmtone/ios/v2-capture-gyroflow/2026-05-08-ios-camera-preview-liquid-glass-research.md`
- Apple Developer: Liquid Glass / `glassEffect` / `GlassEffectContainer`
- Current M12 archive:
  `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-08-m12-advanced-capture-controls.md`

## Subtask Plan

S13-A — **Current UI map** (≈20 min, no code)

Record the current capture screen into four buckets:

- preview content
- top status
- bottom primary controls
- Advanced drawer candidates

Output a short implementation note in this active. Do not audit unrelated
editor UI.

S13-B — **Liquid Glass helper / style consolidation** (≈30 min)

- Add the smallest capture-view-local glass helper(s) needed to avoid repeated
  ad hoc `Color.black.opacity(...)` surfaces.
- Prefer `GlassEffectContainer` / `glassEffect` on iOS 26.
- Provide a non-glass fallback for older availability if the compiler requires
  it.
- Do not create an app-wide design system.

S13-C1 — **Chrome helper extraction** (≈20 min)

- Move S13-B glass helpers into `FilmtoneCaptureChrome.swift`.
- Keep visuals unchanged.
- Register the new Swift file in the Xcode project.

S13-C2 — **Top status extraction** (≈30 min)

- Move close, storage mode, quality contract, duration cap, and manual active
  summary into `FilmtoneCaptureTopStatusBar`.
- Storage must read clearly as `Internal 10s` or `External master`.
- Manual active summary must stay visible when Advanced is collapsed.
- Do not duplicate lens / Look labels already shown in the bottom deck.

S13-D — **Bottom control deck extraction** (≈30 min)

- Move Look strip, lens selector, record / stop, status line, and SSD actions
  into `FilmtoneCaptureBottomDeck`.
- Make Record / Stop the visual anchor.
- Keep Look strip and lens selector near Record, but reduce vertical crowding.
- Preserve one-handed use and leave as much live preview visible as practical.
- Unsafe controls remain disabled while recording / stopping.

S13-E — **Advanced drawer extraction** (≈45 min)

- Move EV, WB, ISO, shutter, and tap focus / meter affordance explanation into
  a collapsed Advanced drawer.
- Drawer closed: show only a compact state summary when non-auto/manual values
  are active.
- Drawer open: expose the existing controls without changing their semantics.
- Do not add new camera controls.

S13-F — **Interaction overlay extraction** (≈20 min)

- Move tap focus / meter hit layer and reticle drawing into
  `FilmtoneCaptureInteractionOverlay`.
- Keep point conversion and session callbacks in `FilmtoneCaptureView`.

S13-G — **Owner walk** (≈15 min)

One product walk is enough:

- open capture
- switch Look
- switch lens
- open / close Advanced
- set manual exposure or WB lock
- record no-SSD 10s
- confirm recording disabled states feel safe

## S13-A Outcome — Current UI Map (2026-05-08)

No-code observation pass of the pre-refactor capture view. Source:
`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift:251`
(body) と各 `private var` セクション。

### 1. Preview content(live image — ZStack 最下層、`.ignoresSafeArea`)

- `previewLayer` (L383) — Metal-backed VDO live preview。VDO 不可の
  format では `AVCaptureVideoPreviewLayer` graceful fallback
- `previewTapInteractionLayer` (L861) — top bar / bottom deck の隙間に
  置いた透明 tap catcher → focus + meter point に変換
- `focusReticle` (L890) — 64pt rectangle、0.6s fade-out

### 2. Top status — `topBar` (L407、`.padding(.top, 8)`)

HStack:
- 左: 閉じる X 丸ボタン(record 中 disabled、`Color.black.opacity(0.45)` Circle 背景)
- 右 VStack(spacing 8):
  - `storagePill` — `Internal master · 10s cap` / `External master · <folder> · 60s cap`
  - `lookReferencePanel` (L476) — 120×90 graded poster thumbnail +
    `LOOK REFERENCE` キャプション + Look 名 + "Live ungraded" 注記
    (live grade 不在時のみ)

### 3. Bottom controls — `bottomDeck` (L542、VStack spacing 16、現状 1 階層)

並び順(state-conditional 可視):

1. preflight error / warnings(出れば赤テキスト)
2. `lensSelector` (L612) — qualify 2+ レンズ時のみ pill row(`0.5× / 1× / 2× / 5×`)
3. `captureLookStrip` (L662) — `Filmtone / Stone / Urban` 3-pill
4. `exposureModeRow` (L1027) — Auto / Manual segmented + manual 時 yellow `ISO · 1/Xs` readout
5. `evSliderRow` (L949) — ±3 stop slider + `+0.7 EV` reset(auto only、range degenerate 時 hide)
6. `isoSliderRow` (L1128) + `shutterSliderRow` (L1164) — manual only、shutter は 180° (1/48s) tick + 24fps cap
7. `whiteBalanceRow` (L1277) — Auto / Locked segmented
8. `contractBanner` (L710) — `4K24 · ProRes422HQ · Apple Log 2 · Cinematic EE · Proxy → Editor`
9. `statusLine` (L738) — `Ready · 10 s max` / `Recording · X.X s left` / `Stopping…`
10. record cluster HStack: `pickFolderButton` 左 / `recordButton` (L798) 中 / `modeToggle` (L820 = SSD 有効時のみ "Clear") 右

### 4. Other layers(no bucket、temporary)

- `failureOverlay` (L1382) — prepare 失敗時 modal
- `diagnosticOverlay` (L1415) — F3-R live preview diagnostics

### Findings(S13-B〜E に直結する観察)

- **背景の単発カードが 23 箇所**(`Color.black.opacity(0.45)` /
  `Color.white.opacity(0.10)〜0.28`)。`glassEffect` / `GlassEffectContainer`
  は **未使用**。S13-B はここを capture-view-local helper(例:
  `captureGlassCapsule(_:)` / `captureGlassRoundedRect(_:)`)で置換すれば
  足りる。app-wide design system を作る必要なし(active.md `Edit Targets`
  通り)
- bottomDeck は **常用(2,3,8,9,10)** と **advanced(4,5,6,7)** が同 VStack
  に直列で、合計最大 7 row 縦積み。S13-D / S13-E は順序を変えずに 4〜7 を
  `DisclosureGroup` 風 drawer に畳むだけで bucket 分離できる
- ただし **manual / WB locked の active 表示は exposureModeRow と
  whiteBalanceRow の segment 自体**(現状の唯一の "active state" UI)。
  drawer に畳むと Product Rule "Manual active state must remain visible
  while Advanced is collapsed" を破る → S13-C の top status か
  drawer-closed summary chip に **collapsed-summary line** が必要
  (例: `Manual · ISO 1213 · 1/48s · WB locked` の 1 行)
- SSD 状態が **`storagePill`(top)** と **`pickFolderButton`(bottom 左)** /
  **`modeToggle`(bottom 右 Clear)** の 3 箇所で表示。S13-C で
  source-of-truth を top status に寄せ、bottom 側を `+/×` icon 1 点に
  縮小する余地あり(片手 reach は維持)
- `contractBanner` は M10 baseline read-only。S13-C で top status 行に
  吸収できる(quality contract は撮影中固定なので bottom に常駐する必要は
  低い)。残置でも害はないが、bottom deck の縦丈短縮には効く
- recording 中 disabled rule は各 row の `.disabled(isRecordingOrStopping)`
  に既に揃っている。drawer の open/close を **追加の `@State Bool`** で
  制御しても disabled 規則と直交可能 — drawer state を session state と
  混ぜない
- **Apple Liquid Glass の sampling 制約**: 現行 `previewLayer` は
  `FilmtoneCaptureLivePreview` (`FilmtoneCaptureLivePreview.swift:139`、
  `UIViewRepresentable` が `MTKView` をラップ)で実装。memory
  `feedback_nsviewrepresentable_blocks_liquid_glass` の通り、
  Apple Liquid Glass は SwiftUI render tree しか sample できないため、
  MTKView 上の `glassEffect` は **live preview pixel を refract / blur
  しない**(`.clear` 系 dramatic refraction は中身が空に見えてしまう)。
  S13-B〜E では `.regular` material(自前 translucency 内蔵)で chrome
  legibility を取りに行き、preview 自体を SwiftUI に refactor する話は
  M13 scope 外で持ち込まない。Active.md "Product Rule" の "improve
  legibility and hierarchy over live video, not as decoration" が
  既にこの制約に整合 — 表現は壊さない

## S13-B/C1 Outcome — Liquid Glass helper extraction (2026-05-08)

S13-B の helper は `FilmtoneCaptureChrome.swift` に移動済み。
deployment target = iOS 26.0 のため `#available` fallback は不要。
prior art は `FilmtoneFullscreenLutEditor.swift` の Liquid Glass treatment。

### 追加した helper

| helper | shape | 適用先 |
|---|---|---|
| `captureGlassCapsule()` | `Capsule()` | row chrome — storage / status / advanced rows |
| `captureGlassPanel(cornerRadius:)` | `RoundedRectangle(cornerRadius:, style: .continuous)` | composite panel chrome, retained as capture-local primitive |
| `captureGlassButton<S: InsettableShape>(in:)` | caller-supplied | button chrome — close X (Circle) / pickFolderButton (RoundedRectangle 12) / modeToggle Clear (RoundedRectangle 12) |

すべて `glassEffect(.regular, in: shape)` のラッパー。tint なし、
interactive なし(S13-B は legibility baseline 専用)。

## S13-C2/D/E/F Outcome — Capture UI split (2026-05-08)

View-only refactor. Session / writer / package / proxy behavior untouched.

New files:

- `FilmtoneCaptureLookModel.swift` — capture-time `FilmtoneCaptureLook`
- `FilmtoneCaptureChrome.swift` — capture-local Liquid Glass primitives
- `FilmtoneCaptureTopStatusBar.swift` — close, storage, quality contract,
  manual/WB active summary
- `FilmtoneCaptureBottomDeck.swift` — lens selector, Look strip, status,
  record / stop, SSD actions
- `FilmtoneCaptureAdvancedDrawer.swift` — collapsed Advanced drawer containing
  EV, exposure mode, ISO, shutter, and WB controls
- `FilmtoneCaptureInteractionOverlay.swift` — tap focus / meter hit layer and
  reticle drawing

Parent `FilmtoneCaptureView.swift` now owns composition and orchestration:

- live preview
- session lifecycle
- state derived from `FilmtoneCaptureSession`
- action callbacks into session / file picker
- failure and diagnostic overlays

Child views receive values and callbacks only. No child view receives
`FilmtoneCaptureSession`.

Size after split:

| file | lines |
|---|---:|
| `FilmtoneCaptureView.swift` | 900 |
| `FilmtoneCaptureTopStatusBar.swift` | 81 |
| `FilmtoneCaptureBottomDeck.swift` | 212 |
| `FilmtoneCaptureAdvancedDrawer.swift` | 388 |
| `FilmtoneCaptureInteractionOverlay.swift` | 47 |
| `FilmtoneCaptureLookModel.swift` | 61 |
| `FilmtoneCaptureChrome.swift` | 24 |

Xcode project registration: all six new Swift files have 4 occurrences in
`project.pbxproj` (build file / file reference / group / sources phase).

Verification:

- `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO`
  → **BUILD SUCCEEDED**

## Done Conditions

1. Record / Stop is visually dominant and easy to hit.
2. Look / lens / storage / duration are understandable without opening
   Advanced.
3. Advanced controls are collapsed by default.
4. Manual active state remains visible while Advanced is collapsed.
5. Liquid Glass is applied only to control layers over preview, not the preview
   content.
6. The screen does not use nested cards or glass-on-glass stacks.
7. Existing M10/M11/M12 behavior remains intact.
8. Owner can complete the S13-G walk without confusion about where primary and
   advanced controls live.

## Stop Conditions

- UI consolidation starts changing capture behavior, writer setup, proxy
  generation, or package schema.
- Liquid Glass adoption requires broad compatibility work outside the capture
  surface.
- Advanced drawer makes manual active state harder to see than the current
  screen.
- The layout hides too much live preview to be useful for shooting.

## Out of Scope

- New capture features.
- Master/proxy export truth.
- Full camera monitoring tools: waveform, false color, focus peaking, zebra.
- New Look library UI.
- React/Capacitor cleanup.
- Broad failure matrix or lens/device matrix.

## Verification

- Swift build after native changes.
- One owner-visible capture UI walk on iPhone 17 Pro.
- No master truth re-matrix unless code touches writer/session behavior, which
  this active should avoid.

## Outcome

S13-G owner walk **PASS** on iPhone 17 Pro #7 / iOS 26.x (device id
`3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`, install via
`xcrun devicectl device install app`). Owner-confirmed checks (3-point
scope, narrowed from 10 by owner direction):

1. Record → 10s → Stop without SSD: PASS
2. Open Advanced drawer → enable Manual exposure → close drawer:
   `Manual · ISO ... · 1/...s` summary remains in top status (drawer
   closed): PASS
3. Recording-in-progress: SSD / lens / Look unsafe controls remain
   `disabled`: PASS

Owner verdict: 「目視動作では大きな異常はなかった」. No regressions
observed on the split UI. Owner then rejected the experience quality as
too plain /突貫工事, so this archive is evidence for the split pass only,
not final M13 completion. Current work continues in `active.md` as M13-I.

## S13-H Outcome — Capture Screen Experience Pass (2026-05-08)

Direction lock: **Cinematic Liquid Glass Camera**. This is a view-layer
experience pass only; `FilmtoneCaptureSession`, writer, package, proxy,
and master/proxy truth remain untouched.

Implemented:

- Capture-local chrome tokens and haptic helpers in
  `FilmtoneCaptureChrome.swift`.
- Hero Record / Stop control in `FilmtoneCaptureBottomDeck.swift`:
  larger control, red core, recording pulse/ring, tighter status readout,
  and local impact haptic.
- Look and lens rails now use stronger selected contrast, glass glow,
  light spring scale, and selection haptic.
- SSD / Clear actions are reduced to compact icon controls so Record
  remains the visual center.
- Top camera HUD is compressed to `Internal 10s` / `External master`,
  `4K24 · Log2 · ProRes`, and a yellow manual/WB summary when relevant.
- Advanced drawer header is camera-state based (`Auto`,
  `Manual · ISO ...`, `WB Locked`) rather than a settings-style label.

Verification:

- Simulator build: `** BUILD SUCCEEDED **`
- Device build: `** BUILD SUCCEEDED **`
- Device install + launch: iPhone 17 Pro #7 /
  `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`
- `git diff --check`: clean

S13-H owner walk remained intentionally small:

1. Record / Stop is visually and tactilely the primary action.
2. Look / lens switching feels clear and responsive.
3. Manual state remains visible when Advanced is closed.

Owner follow-up after this install: S13-H improved the screen only partially
(roughly 40% acceptable) and still did not solve the root experience problem.
Do not close M13 from this archive alone.

Verification ledger:

- Simulator build: `** BUILD SUCCEEDED **`
  (`xcodebuild ... iOS Simulator Debug CODE_SIGNING_ALLOWED=NO`)
- Device build: `** BUILD SUCCEEDED **`
  (`xcodebuild ... -destination id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9
  -configuration Debug`)
- pbxproj 4-section registration: 6/6 new files (4 occurrences each)
- `git diff --check`: clean
- Master truth re-matrix: not run — writer/session/package/proxy
  behavior untouched, view-layer-only refactor (Stop Conditions
  invariant)

Files in the split pass:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureView.swift`
  (orchestrator, 900 lines)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureChrome.swift`
  (Liquid Glass primitives, 24 lines)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureLookModel.swift`
  (capture-time Look enum, 61 lines)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureTopStatusBar.swift`
  (close / storage / quality contract / manual+WB summary, 81 lines)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureBottomDeck.swift`
  (Look strip / lens / status / record-stop / SSD action, 212 lines)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureAdvancedDrawer.swift`
  (collapsed-by-default EV / exposure mode / ISO / shutter / WB,
  388 lines)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureInteractionOverlay.swift`
  (tap focus / meter hit layer + reticle, 47 lines)

Children receive values + callbacks only — `FilmtoneCaptureSession` is
not threaded into any child view, preserving the orchestrator boundary.

Out-of-scope follow-ups (deferred, not blocking):

- React/Capacitor purge (lane already noted post-M7)
- Live preview SwiftUI refactor (would unlock Apple Liquid Glass
  refraction over preview; M13 explicitly out-of-scope per Product Rule
  + `feedback_nsviewrepresentable_blocks_liquid_glass`)
- Master/proxy export truth re-matrix (only required if writer/session
  semantics change in a future lane)
