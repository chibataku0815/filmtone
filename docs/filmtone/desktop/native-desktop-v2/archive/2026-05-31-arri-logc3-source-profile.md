# Native Desktop v2 Active Task: ARRI LogC3 Source Profile

Milestone: M3 / M4 parity hardening

Goal: Add ARRI LogC3 as a built-in Source Profile across core TS, iOS, and native Desktop using Filmtone normalized Rec.709 math.

Edit targets:
- `packages/film-lab-core/src/source-profile-conversion.ts`
- `packages/film-lab-core/src/source-profile-conversion.test.ts`
- `packages/film-lab-core/src/source-detail-compensation.ts`
- `packages/film-lab-ui/src/LUTPanel.tsx`
- iOS source profile catalog/schema/math/export/strings and fixtures
- native Desktop source profile catalog/math/input transform/tests

Read-only references:
- ARRI Log C docs and ALEXA Log C Curve PDF
- Panasonic S1II ARRI LogC3 product note
- Existing V-Log / S-Log3 / Canon Log 3 Source Profile implementation

Checklist:
- [x] Add `built-in:source-profile.arri-logc3` to shared catalogs and UI ordering.
- [x] Implement LogC3 EI800 exposure-value decode + AWG3 -> Rec.709 + Filmtone SDR shoulder.
- [x] Add iOS fixture generator, fixtures, Swift accuracy gate, and TS parity coverage.
- [x] Mirror Swift math/catalog/export wiring in native Desktop.
- [x] Classify ARRI LogC3 in source detail compensation.
- [x] Rebuild generated core dist and run focused/full verification.
- [x] Record copy/history impact, archive this active task, and append a short strategy note.

Verification:
- `bun test packages/film-lab-core/src/source-profile-conversion.test.ts`
- `bun run build:core`
- `bun run verify:desktop`
- `bun run verify:ios`
- `bun run check:filmtone-context`
- `git diff --check`

Done conditions:
- ARRI LogC3 appears as a manual Source Profile in shared UI, iOS, and native Desktop.
- Preview/export paths build/apply the same normalized conversion on TS/iOS/macOS surfaces.
- Sidecar/profile identity uses the new catalog id and curve.
- Fixture and parity tests cover linearization, Macbeth patches, and cube generation.

Stop conditions:
- Done conditions met.
- Unexpected licensing or source-truth issue makes the built-in transform unsafe.
- 3 consecutive verification failures on the same unresolved root cause.

Out of scope:
- Official ARRI Classic 709 / K1S1 LUT bundling.
- ARRI LogC3 auto-detection without reliable probe metadata.
- Public release copy drafting.

Unexpected blockers:
- None yet.

Copy / History Impact:
- UI/source-profile label impact only: `ARRI LogC3` appears as a manual Source Profile across shared UI, iOS, and native Desktop.
- No public release copy drafted in this task.

Article Opportunity: Release-note only now; short post only after S1II visual validation with real footage.

Change-History Opportunity: Developer note. The source-profile catalog gained a synthesized ARRI LogC3/AWG3 normalization transform; no broad implementation-history rewrite needed.

Verification log:
- `bun test packages/film-lab-core/src/source-profile-conversion.test.ts` - pass, 27/27.
- `bun test packages/film-lab-core/src/source-detail-compensation.test.ts` - pass, 22/22.
- `bun run build:core` - pass.
- `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract` - pass, including ARRI LogC3 accuracy gate.
- `bun run verify:desktop` - pass, Xcode build succeeded.
- `bun run verify:ios` - pass, including ARRI LogC3 accuracy gate.
- `apps/filmtone-desktop-macos/Verify/run.sh` - pass, 156/156.
- `bun run check:filmtone-context` - pass.
- `git diff --check` - pass.

Done:
- ARRI LogC3 is implemented as a Filmtone-normalized manual Source Profile across shared core, shared UI, iOS, and native Desktop.
- The official ARRI 709 looks remain out of scope; no ARRI Classic 709 / K1S1 LUT was bundled.
