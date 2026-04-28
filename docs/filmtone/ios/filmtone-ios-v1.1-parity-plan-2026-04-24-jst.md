# Filmtone iOS v1.1 — Desktop v1.0.3 Parity Plan

- Date: 2026-04-24 JST
- Scope owner: iOS native Phase0 / Filmtone export pipeline
- Source gap analysis: `docs/filmtone/ios/filmtone-ios-parity-gap-vs-desktop-v1.0.3-2026-04-24-jst.md`
- Task docs: `docs/filmtone/ios-v1.1-tasks/README.md`

## 1. Goal

iOS v1.1 は Desktop v1.0.3 候補との差分をすべて潰すリリースではない。目的は、iOS がすでに持っている処理や取得済み metadata を **ユーザーと Desktop round-trip に見える形へ変える** こと。

Primary outcome:

1. HDR / wide-gamut source を silent に扱わず、probe / UI / sidecar に policy と reason を残す
2. Export artifact に grade / source / optics / policy を復元可能な sidecar として保存する
3. 取得済み camera optics を renderer と UI に反映する
4. color / display / FPS trust を source metadata として扱える DTO を作る
5. iOS generated contract の drift を検知できるようにする

## 2. Non-goals

- Desktop と完全同一の HDR→SDR 色変換を v1.1 で保証しない
- Cross Filter native 実装は v1.1 に入れない
- Depth map pipeline と depth-aware bloom / halation / diffusion は v1.1 に入れない
- PNG / MOV / ProRes / batch export は v1.1 の必須要件にしない
- Photos asset の隣に sidecar JSON を保存できる前提を置かない

## 3. Release Scope

| Track | Task | Priority | Target |
|------|------|----------|--------|
| T1 | HDR source visibility + policy notice | P0 | v1.1 |
| T2 | Export sidecar JSON | P0 | v1.1 |
| T3 | Camera optics renderer wiring | P1 | v1.1 |
| T4 | Source video metadata DTO + FPS/rotation QA | P1 | v1.1 |
| T5 | Camera optics UI label | P1 | v1.1 |
| T6 | Contract regeneration guardrails | P1 | v1.1 |
| T7 | Cross Filter native parity | P2 | v1.2 candidate |
| T8 | Depth coupling native pipeline | P2 | v1.2 candidate |
| T9 | Progressive preview quality badge | P3 | design backlog |
| T10 | Export format / Files workflow | P3 | design backlog |

## 4. Implementation Order

### Milestone M0 — Contract and DTO foundation

- Add source color / HDR / display / timing DTOs
- Decide iOS sidecar schema mapping against Desktop `export-metadata-session.ts`
- Add contract regeneration check so hidden defaults can be consumed without UI exposure

Exit criteria:

- DTOs compile on native iOS and are serializable through Capacitor
- fixture JSON proves backward compatibility for existing requests

### Milestone M1 — Source visibility

- Extend `SourceProbeService.swift`
- Surface HDR policy notice in SwiftUI
- Surface camera optics label in preview/export UI

Exit criteria:

- HDR / SDR / unknown fixtures produce distinct UI state
- Existing SDR sources show no warning
- optics label distinguishes metadata vs assumed

### Milestone M2 — Sidecar

- Build iOS export sidecar payload
- Write sidecar beside temporary export artifact in app container
- Share media + sidecar through share sheet

Exit criteria:

- Desktop can parse or gracefully accept the iOS sidecar
- A user can AirDrop media + JSON from iOS

### Milestone M3 — Optics rendering

- Port ray-angle optics math
- Apply optics field mask to existing Core Image stages
- Add snapshot / numeric smoke coverage for wide vs tele optics

Exit criteria:

- same source with metadata HFOV and assumed HFOV produces measurable edge-field difference
- no visual change for missing optics beyond current assumed fallback

### Milestone M4 — QA and release gate

- Verify portrait export, HDR notice, sidecar, share, save-to-Photos
- Run Swift contract verification and existing app tests
- Update release checklist

Exit criteria:

- v1.0 behavior remains stable for SDR / normal MP4
- no warning appears for standard SDR BT.709 sources
- all P0/P1 task acceptance criteria are met

## 5. Task Index

- Index: `docs/filmtone/ios-v1.1-tasks/README.md`
- T1: `docs/filmtone/ios-v1.1-tasks/01-hdr-source-visibility-policy.md`
- T2: `docs/filmtone/ios-v1.1-tasks/02-export-sidecar-json.md`
- T3: `docs/filmtone/ios-v1.1-tasks/03-camera-optics-renderer-wiring.md`
- T4: `docs/filmtone/ios-v1.1-tasks/04-source-video-metadata-fps-rotation.md`
- T5: `docs/filmtone/ios-v1.1-tasks/05-camera-optics-ui-label.md`
- T6: `docs/filmtone/ios-v1.1-tasks/06-contract-regeneration-guardrails.md`
- T7: `docs/filmtone/ios-v1.1-tasks/07-cross-filter-native-parity.md`
- T8: `docs/filmtone/ios-v1.1-tasks/08-depth-coupling-native-pipeline.md`
- T9: `docs/filmtone/ios-v1.1-tasks/09-progressive-preview-quality-badge.md`
- T10: `docs/filmtone/ios-v1.1-tasks/10-export-format-files-workflow.md`

## 6. Release Gate Checklist

- HDR source produces visible iOS policy notice and sidecar metadata
- SDR BT.709 source produces no HDR warning
- Export sidecar includes app version, grade, preset, source probe, source metadata, camera optics, HDR policy
- Share sheet can export media + sidecar together
- Save to Photos still saves media successfully
- Portrait video export remains correctly oriented
- Camera optics label appears for metadata and assumed optics
- Contract generation check fails on Desktop/iOS preset drift
- Cross Filter and depth coupling are explicitly documented as v1.2 deferred, not silent omissions
