# Rec.709-Safe Built-in Look Application

Milestone: M3 / M4 parity hardening
Opened: 2026-05-16 JST

## Goal

Make Creative Pack 01 built-in Looks apply through a source-aware policy so
Rec.709 / display-referred sources use a safer effective Look intensity while
Log / selected Source Profile material keeps the full creative path.

## Edit Targets

- Shared Creative Pack 01 source policy in `packages/film-lab-core/`
- iOS Look Director and resolver call sites under `apps/capacitor-film-lab-ios/`
- Native Desktop grade resolution / render entry points under
  `apps/filmtone-desktop-macos/`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `apps/filmtone-desktop-macos/README.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`

## Checklist

- [x] Add Creative Pack 01 source policy metadata and tests.
- [x] Add iOS Rec.709 safe Look Director branch and resolver coverage.
- [x] Thread source color class into iOS built-in Look apply / refresh paths.
- [x] Add macOS effective intensity policy for bundled built-in Looks.
- [x] Verify focused core / iOS / Desktop checks.

## Verification

- `bun run build:core`
- `bun run verify:ios`
- `bun run verify:desktop`
- `git diff --check`

## Done Conditions

- Rec.709 / unknown display sources clamp built-in Creative Pack 01 Look
  intensity to Stone 0.86, Urban 0.84, Noir 0.92.
- Log / explicit non-Rec.709 Source Profile material keeps the full branch.
- User-imported / imported-grade package LUTs are not silently clamped.

## Stop Conditions

- Done conditions met.
- Unexpected schema or product scope expansion is required.
- Three consecutive verification failures on the same check.

## Out Of Scope

- Public copy, warning UI, release metadata, and broad media QA.
- Replacing the current Rec.709 SDR output contract with ACES / OCIO.

## Unexpected Blockers

- None.

## Completion Log

- Creative Pack 01 now declares `display-rec709-normalized` source policy and
  Rec.709 safe ceilings: Stone 0.86, Urban 0.84, Noir 0.92.
- iOS Look Director now resolves a Rec.709-safe branch for SDR/unknown display
  sources and preserves the full branch for Log / explicit Source Profiles.
- Native Desktop applies the same ceiling only to bundled built-in Looks with
  pinned catalog LUT hashes; imported/package LUTs are left unchanged.

## Verification Result

- Passed: `bun run build:core`
- Passed: `bun test packages/film-lab-core/src/creative-pack-01.test.ts`
- Passed: `bun run verify:ios`
- Passed: `bun run verify:desktop`
- Passed: `git diff --check`
- Passed: `bun run check:filmtone-context`

No copy/history impact: no public copy, release claims, or implementation
history wording changed.
Article Opportunity: Developer note.
Change-History Opportunity: Developer note.
