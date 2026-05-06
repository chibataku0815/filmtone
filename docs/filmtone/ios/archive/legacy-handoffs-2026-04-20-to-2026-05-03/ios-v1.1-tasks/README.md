# Filmtone iOS v1.1 Task Docs

- Parent plan: `../filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`
- Gap analysis: `../filmtone-ios-parity-gap-vs-desktop-v1.0.3-2026-04-24-jst.md`
- Date: 2026-04-24 JST

## Task Index

| ID | Task | Priority | Target |
|----|------|----------|--------|
| T1 | `01-hdr-source-visibility-policy.md` | P0 | iOS v1.1 |
| T2 | `02-export-sidecar-json.md` | P0 | iOS v1.1 |
| T3 | `03-camera-optics-renderer-wiring.md` | P1 | iOS v1.1 |
| T4 | `04-source-video-metadata-fps-rotation.md` | P1 | iOS v1.1 |
| T5 | `05-camera-optics-ui-label.md` | P1 | iOS v1.1 |
| T6 | `06-contract-regeneration-guardrails.md` | P1 | iOS v1.1 |
| T7 | `07-cross-filter-native-parity.md` | P2 | v1.2 candidate |
| T8 | `08-depth-coupling-native-pipeline.md` | P2 | v1.2 candidate |
| T9 | `09-progressive-preview-quality-badge.md` | P3 | design backlog |
| T10 | `10-export-format-files-workflow.md` | P3 | design backlog |

## v1.1 Required Bundle

T1 through T6 should ship together. T1 without T2 makes HDR policy visible but not portable. T3 without T5 uses optics without telling the user which optics were used. T6 keeps T3 and future T7/T8 from depending on stale hand-copied defaults.

## Deferred Bundle

T7 and T8 are deliberately outside v1.1. They change the native rendering surface area and need visual fixtures before release pressure is applied.

## Design Backlog

T9 and T10 need product decisions before implementation. They should not block the metadata/policy/sidecar release unless a user-facing workflow demands them.
