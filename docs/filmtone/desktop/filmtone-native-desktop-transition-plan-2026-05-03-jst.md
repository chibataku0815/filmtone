# Filmtone Native Desktop Transition Plan

Date: 2026-05-03 JST

Worktree:
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`

Branch: `feature/native-desktop-plan`

This file is the canonical index. Keep it short. Detailed plan material lives in:

```text
docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/
```

## Current State

- **Phase 0 (Contract & Skeleton): COMPLETE** (commit `398743c`).
- **Phase 1a (Open + Preview precondition): COMPLETE** (commit `398743c`).
- **Phase 1b (Vertical Slice — still): COMPLETE** (uncommitted on top of `398743c`).
  preset → grade → still export → sidecar JSON wired. macOS↔source ∞dB
  bit-identical for reset preset. baseline-B 13.69 dB is **informational** —
  fixture mismatch with iOS canonical CIColorKernel pipeline (06 risk row).
- **Phase 1c (Vertical Slice — video): COMPLETE** (uncommitted on top of `398743c`).
  open .mp4/.mov → midpoint frame preview → AVAssetReader → CIImage → grade →
  CIContext.render(to:CVPixelBuffer) → AVAssetWriter H.264 mp4 → sidecar
  (`sourceKind:"video"` additive, Case B 継続). Output mp4 is Rec.709 SDR
  (color_space/transfer/primaries=bt709). iphone vs reset frame 0 PSNR 14.91 dB
  proves grade chain active in video path.
- **Phase 2 C1+C2 (Foundation: DTO port + AVFoundation modern async):
  COMPLETE** (uncommitted on top of `398743c`). SourceColor DTO graph
  (`SourceColorClassDTO` / `SourceLogTransferFunctionDTO` / `SourceColorMetadataDTO`)
  ported to `Domain/SourceColorTypes.swift`; classifier + normalizer
  ported to `Color/`; `FilmtoneColorPipeline.defaultOutputContract` factory
  landed in `Color/FilmtoneColorPipeline.swift` (`phase1cMP4Default()` 削除);
  `Media/FilmtoneSourceProber.swift` (async video probe + still CGImageSource
  probe) + `Media/FormatExtensionReader.swift` 追加. Reader rebuilt to
  accept `FilmtoneVideoTrackProbe` (eliminates deprecated `asset.tracks` /
  `track.naturalSize` / `.preferredTransform` / `.nominalFrameRate` /
  `.duration` / `AVAssetImageGenerator.copyCGImage`). Sidecar additive
  `sourceInterpretation` (Phase 2 acceptance "Source profile id round-trips").
  All 6 AVFoundation sync deprecation sites resolved. `verify:macos` BUILD
  SUCCEEDED, generator drift 0, iOS↔macOS Phase0Generated bit-identical,
  iOS / Electron / core src clean. Phase 1b regression: macOS↔source still
  ∞dB; iphone on 09-skin-light **40.60 dB** (was 39.62 dB) — marginal
  tighter source color interpretation aligned with iOS canonical
  (sRGB fallback colorSpace + `applyOrientationProperty:true`).
- **Phase 2 C3 truth gate scaffold: COMPLETE** (uncommitted on top of `398743c`).
  `apps/desktop-film-lab-batch/test/golden/baseline-C/{reset,iphone,softBlue,
  amberGlow}/` + README explaining iOS Simulator workflow;
  `scripts/golden-parity-ios-vs-macos.ts` PENDING-aware harness drives macOS
  CLI for each (preset, image), compares against `baseline-C/<preset>/<image>.png`
  if populated. baseline-C content itself is **PENDING** until user runs
  iOS Simulator workflow to populate the 4×10=40 still cells.
- **Next: Phase 2 C3 baseline-C populate → C5/C6/C7 priority re-judgement
  pending OpticalFilters main landing.** Per chunk-着手 user 確定 (2026-05-03
  JST late evening): C5 (OpticalFilters main 着地後合流) / C6 (SPM 化、急がない
  方針維持) / C7 (IOSurface perf bench) は C3 結果 + main landing 状況で
  再判断する (現時点で固定しない)。

## Read Order

1. [01-current-state-and-decision.md](native-desktop-transition-plan-2026-05-03-jst/01-current-state-and-decision.md)
   - status, purpose, product decision, current platform facts
2. [02-target-architecture-and-contracts.md](native-desktop-transition-plan-2026-05-03-jst/02-target-architecture-and-contracts.md)
   - app shell, media/render core, performance render spine, data contract
3. [03-migration-and-concurrent-lanes.md](native-desktop-transition-plan-2026-05-03-jst/03-migration-and-concurrent-lanes.md)
   - parallel migration strategy and Desktop Look Unification dependency
4. [04-phase-plan.md](native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md)
   - Phase 0-5 deliverables, gates, verification, first implementation order
5. [05-future-lanes.md](native-desktop-transition-plan-2026-05-03-jst/05-future-lanes.md)
   - Continuity Export on Mac and Resolve / Pro NLE integration
6. [06-quality-gates-risks.md](native-desktop-transition-plan-2026-05-03-jst/06-quality-gates-risks.md)
   - quality gates, open questions, risks, definition of done

## Core Rule

Native Desktop v2 is a parallel product lane. Electron Desktop remains the
shipping rail until the native app beats it on preview/export quality.

UI framework stance:

- SwiftUI-first for new native UI.
- AppKit only for macOS-specific interop and deep platform behavior.
- UIKit stays iOS-only; AppKit is never an iOS strategy.

Do not let documentation, release shell, CloudKit/Handoff, Resolve, OFX, DCTL,
or public copy work delay the next product proof:

```text
Phase 2 C3 (truth gate populate): iOS Simulator → baseline-C/{reset,iphone,
softBlue,amberGlow}/<image>.png (4×10 cells) → bun run scripts/
golden-parity-ios-vs-macos.ts で各セル PSNR 確認 → 結果次第で
WGSL→Metal port 必要性 + C5/C6/C7 優先付け再判断。
```

## Canonical Handoffs

- Phase 0 completion:
  [filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md](filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md)
- Phase 1a completion / Phase 1b entry:
  [filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md](filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md)
- Phase 1b completion:
  [filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md](filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md)
- Phase 1c master / entry (self-contained):
  [filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md](filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md)
- Phase 1c completion:
  [filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md](filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md)
- **Phase 2 C1+C2+C3 scaffold master (current, self-contained):**
  [filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md](filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md)
- Phase 0 internal design plan:
  `~/.claude/plans/luminous-sparking-eclipse.md`

## Update Policy

- Keep this index under roughly 100 lines.
- Put detailed changes into the numbered files.
- If a new implementation handoff supersedes the current phase, update
  `Current State` and `Canonical Handoffs` here.
- Keep links relative so this file works inside the worktree and in GitHub.
