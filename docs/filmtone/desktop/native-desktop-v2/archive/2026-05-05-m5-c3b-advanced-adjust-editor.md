# M5-C.3b Advanced Per-Parameter Override Editing UX (Desktop)

Date opened: 2026-05-05 JST (auto-mode、Tier C 5-gap 5 件目 = 最終)

**Status: CLOSED 2026-05-05** — commit `495132f7`. **Option B (popover)**
implemented in auto-mode after user directive. Detail in §"Status (added
at archive time)" at the bottom of this file.

## Milestone

M5 Native Editing UI / detail editing slice。strategy.md "2026-05-04 user
smoke で 5 個の追加ギャップ判明" の **M5-C.3b** = 5-gap 5 件目。
User smoke #2「iosでいう調整ボタンと詳細変更ができない」直接対応。

## Goal

Filmtone Desktop 上で iOS canonical `FilmtoneStrengthSheet` +
`FilmtoneAdjustmentHelpSheet` 相当の 30 個前後の paramOverrides を
直接編集できる UX を提供する。Override の storage / apply 経路は
M5-C.3a で lit up 済み (`paramOverrides: FilmtonePhase0ParamsPatch`)、
今 slice は **編集 surface だけ**。

## Why this slice

- User smoke #2 直接対応。Quick adjust 3 軸 (filmCharacter / era /
  dynamics) だけでは iOS canonical の細かな grade 表現ができない。
- 1.4 公開時 iOS との feature parity の最後のピース。Desktop に
  「detail 不在」が残ると Filmtone の Desktop 版は iOS の subset と
  認識される (実際は逆 — Desktop が master / 4K-capable exporter で
  あるべき)。
- Storage round-trip は M5-C.3a で済 → editing UI を足すだけで Save
  Look 機能と完全統合される (override を含む Look の保存 / 復元が
  即動く)。

## UX shape decision (review needed)

strategy.md は「right-rail 拡張 panel か popover で適合化」と 2 択を
提示。両方 macOS HIG canonical だが trade-off が異なる。

### Option A: Right-rail Disclosure Panel

新 panel `AdvancedAdjustControls` を `QuickAdjustControls` と
`GradeControls` の間に追加 (右レール内 7 panel 目)。`DisclosureGroup`
で category 別 (color / curves / optics / film grain / etc.) に
collapsed-by-default、展開すると 5-8 個の `Slider` row。

**Pros:**
- Always-visible state (現 override が一目で全体像)
- 既存 right-rail glass posture と完全整合 (`.clear.tint(.black.opacity(0.30))`)
- Save Look の preview 中、override 状態が画面に出続ける
- Apple HIG: persistent state は inline、transient は sheet/popover

**Cons:**
- 右レールが大きく伸びる (現 5 panel + 30 row 展開時 → scroll 必須)
- Window-shape との trade-off: 右レール固定幅 220pt の中で 30 slider
  を読みやすく描画するのは tight
- Category が collapsed 状態でも row label が並ぶ → 縦スクロール量増加

### Option B: "Adjust…" Popover from Right-rail Button

QuickAdjustControls 末尾 (Reset Quick の隣) に「Adjust…」button 追加。
押下で `Popover` (anchor = button) が開き、内部に専用 advanced editor。
Popover サイズ ~480×600pt 程度、内部に DisclosureGroup + Slider grid。

**Pros:**
- 右レール本体は今の 5 panel posture を維持 (visual hierarchy 保持)
- 編集中だけ広い editing area が confined に開く (focused editing UX)
- Apple HIG: detail editing は Popover (Inspector の inspector pattern)
- Popover 自体に `.glassEffect` 適用すれば Liquid Glass family に統一可

**Cons:**
- Popover を閉じると override 全体像が見えなくなる (Quick adjust の
  3 axis は依然 inline で、advanced は hide)
- "Adjust…" button の追加 = M5-F.1 で触らなかった `.buttonStyle(.glass)`
  posture の追加適用 (整合は取れる)
- Popover 内に scrollable content を持つので keyboard nav が複雑化

### Recommendation

**Option B (Popover)** を推奨。理由:
- 右レール 5 panel の現視覚秩序を崩さない (M5-B Pass 1-4 + M5-D.1 で
  揃えた glass family を保てる)
- macOS canonical: detail-editing inspector は popover (`.popover()`)
- "Adjust…" entry point は QuickAdjust の延長として discoverable
- Override 全体像は現状でも `paramOverrides.summary` のような
  short caption で QuickAdjust panel に表示可能 (collapsed view)
- Popover 内なら Slider grid を 480×600pt で 30 row 余裕

User 判断が分かれた時の対案: **Option A** にすれば iOS sheet との
mental model 親和性 (sheet ↔ panel いずれも always-visible inline-ish)
が強い、と擁護できる。

## Scope (Option B 採用時)

### In

1. **AdvancedAdjustEditor.swift 新規作成**
   - Popover 内部 View
   - DisclosureGroup × 5 category (catalog mapping は
     `FilmtonePhase0Params` の field 区分に従う)
   - 各 group 内 ~6 Slider row (label + value chip + Slider + reset)
   - "Reset All Overrides" button (overall)
2. **QuickAdjustControls 拡張**
   - 末尾に "Adjust…" button (`.buttonStyle(.glass)` + `.controlSize(.small)`)
   - `.popover(isPresented:)` で `AdvancedAdjustEditor` を anchor
   - Override 概要 chip (例: "12 / 30 active") を Reset Quick 隣に inline
3. **EditorState 拡張**
   - `paramOverrides` への per-key bind helper (Slider value ↔ patch field の
     read/write convenience)。`FilmtonePhase0ParamsPatch` の各 optional
     field を Binding<Double> 化する subscript 系
   - `clearAllOverrides()` メソッド
4. **Slider category catalog**
   - 30 field を読み込み・更新する category 一覧 (static constant)。
     iOS canonical の category 順序に合わせる
5. **Visual style**
   - DisclosureGroup label `.font(.callout.weight(.semibold))`
   - Popover 自身の `.glassEffect(.clear.tint(.black.opacity(0.40)))` で
     右レール panel より強い tint (popover 内の readability 確保)
6. **build verify**
   - `xcodebuild Debug` PASS、Swift 6 strict concurrency warning なし
7. **commit (single — large slice なので diff は大きい)**

### Out (deferred / out of scope)

- iOS canonical sheet の full visual mirroring (Desktop UX は popover
  posture が canonical)
- AdjustmentHelpSheet 相当の説明テキスト (今 slice は editing surface
  のみ、help / tooltip layer は別 slice)
- Per-slider unit / curve hint / range canonical mapping detail (iOS
  catalog から transcribe する一覧を用意する作業は user 確認後)
- Search / filter for override fields
- Preset reset to default per category

## Approach (Option B 採用時)

```
QuickAdjustControls right-rail panel:
┌──────────────────────────────┐
│ Quick Adjust                 │
│  Film Character ───●─        │
│  Era            ─●──         │
│  Dynamics       ──●          │
│ [Reset Quick] [Adjust…] 12/30│
└──────────────────────────────┘
                ↓ (popover anchor)
┌────────────────────────────────────┐
│ Advanced Adjust              ✕    │
│ ▶ Color (3)                       │
│ ▼ Curves (5)                      │
│   Black Point  -0.05 ─●──── [↺]  │
│   Highlight     0.30 ───●── [↺]  │
│   ...                             │
│ ▶ Optics (4)                      │
│ ▶ Film Grain (3)                  │
│ ▶ Hue/Sat (15)                    │
│              [Reset All Overrides]│
└────────────────────────────────────┘
```

## Done conditions (Option B)

- "Adjust…" button が QuickAdjustControls に出現、popover open ↔ close
- 30 paramOverrides field を category 別 5 group に整理した catalog
  が landed
- 各 Slider row が `paramOverrides` の対応 optional field と双方向 bind、
  per-row reset button が field を nil に戻す
- "Reset All Overrides" が `paramOverrides = .empty` を call
- Save Look が popover 内編集 state を sidecar に persist (M5-C.3a 経路で
  既動く想定 — verify する)
- Popover の glass posture が右レール chrome と family 整合
- xcodebuild Debug PASS

## Edit Targets (Option B)

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustEditor.swift` (new)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift` (subscript helpers)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustCatalog.swift` (new — static category mapping)

## Read-Only References

- iOS canonical:
  - `apps/capacitor-film-lab-ios/ios/App/.../FilmtoneStrengthSheet.swift`
  - `apps/capacitor-film-lab-ios/ios/App/.../FilmtoneAdjustmentHelpSheet.swift`
- Shared core:
  - `packages/film-lab-swift-core/Sources/.../FilmtonePhase0ParamsPatch.swift`
    (30 field の正本 catalog)
- Desktop:
  - `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
    (entry point + Reset Quick の placement reference)

## Out Of Scope

- Help / tooltip layer (M5-C.3c 候補)
- Per-field unit / display formatter customization (canonical transcribe 後)
- Search across 30 fields
- Reset-per-category buttons
- iOS sheet の visual mirroring (intentional divergence)

## Estimated size

~3-4h (半日)。30 field × Slider row + popover infra + bind helpers + catalog
+ smoke。当初 strategy 推定「~半日」と整合。

## Operating mode

**Auto-mode、ただし UX shape (Option A vs Option B) 判断 + 30 field
category catalog の transcribe 確認は user review が望ましいため、
implementation 着手前に明示的に user 承認を取る。**

承認後の実装は agent が連続着手 (commit 含む)。

## Status (added at archive time)

**Closed 2026-05-05** — commit `495132f7` (7 files, +698/-8). Picked
**Option B (popover)** so the 30+ row editing surface gets 480×600pt
to breathe instead of fighting the 220pt right-rail width.

Implementation details, the responsibility-separation course
correction (catalog → `Domain/`, editing helpers →
`State/EditorState+ParamOverrides.swift` extension), and the 5/5
gap closure recap live in `strategy.md` Completion Log under the
2026-05-05 M5-C.3b entry.

A 2026-05-05 multi-agent review surfaced 4 architecture / coverage
gaps that landed against M5-C.3b (P2 RootWindowView export
orchestration, P2 missing Verify coverage, P2 catalog parity gap,
P3 LibraryViewModel coupling). Those were addressed in the M5-G
Architecture Thin Cuts slice — see
`archive/2026-05-05-m5-g-architecture-thin-cuts.md`.
