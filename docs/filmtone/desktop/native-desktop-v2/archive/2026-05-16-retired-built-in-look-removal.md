# Active — Retired Built-In Look Removal Cleanup

Inserted 2026-05-16 JST as an owner-directed cleanup after the Codex
AI-native MVP interrupt.

## Milestone

Interrupt / cleanup.

## Goal

Remove the retired preset-only bundled Look from current Filmtone
implementation and active product state. It must not remain as a selectable
built-in Look, built-in catalog entry, verification expectation, or current
active lane.

## Edit Targets

- `apps/capacitor-film-lab-ios/`
- `apps/filmtone-desktop-macos/`
- Native Desktop v2 lane docs under
  `docs/filmtone/desktop/native-desktop-v2/`
- Generated/package declaration drift only if verification/build updates it.

## Read-Only References

- Historical archives and paused files are evidence unless they conflict with
  the owner instruction to remove this built-in from current implementation.
- Existing Codex MCP implementation changes are unrelated and must not be
  reverted.

## Checklist

- [x] Locate all current references.
- [x] Remove the entry from iOS built-in Look catalog.
- [x] Remove the entry from Native Desktop built-in Look catalog/runtime helpers.
- [x] Remove entry-specific verify assertions.
- [x] Update current lane/strategy notes so the retired built-in is cleanup-only.
- [x] Run focused verification and whitespace checks.
- [x] Archive this active lane when done.

## Verification

- `bash apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run verify:desktop`
- Absence grep for the removed built-in name, slug, and UUID.
- `git diff --check`

## Done Conditions

- The retired built-in has no current implementation references in app/package
  sources.
- Desktop verify harness and Desktop app verification pass.
- Any remaining references are explicitly outside current implementation.

## Stop Conditions

- Verification fails 3 consecutive times for the same reason.
- Removal requires generated Swift regeneration beyond this cleanup scope.
- Removal conflicts with unrelated in-progress Codex MCP work.

## Out Of Scope

- Release publication, version metadata, App Store copy, and portfolio updates.
- Codex MCP feature changes.
- Deleting unrelated historical archive evidence unless explicitly requested.

## Completion Log — 2026-05-16 JST

Changed:

- Removed the retired preset-only built-in from iOS and Native Desktop built-in
  Look catalogs.
- Removed the Desktop-only preset-only built-in helper path and routed saved
  built-in immutability / favorite / load behavior through the remaining
  Creative LUT catalog entries.
- Removed the retired entry's Desktop verify assertions and cleaned current
  strategy / Codex archive notes so no current implementation doc points at it.

Verification:

- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed (`144/144`).
- `bun run build:filmtone-automation` passed.
- `bun run verify:desktop` passed.
- `bun run verify:ios` passed.
- Absence grep for the removed built-in name, slug, UUID, and old helper names
  returned no results.
- `git diff --check` passed.
- `bun run check:filmtone-context` passed.

No copy/history impact: removal only deletes a non-public retired built-in
implementation path and current internal notes; release metadata and public
copy are unchanged.

Article Opportunity: No story.

Change-History Opportunity: No story.
