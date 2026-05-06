# Filmtone iOS Source Profile Handoff: DJI D-Log / Canon C-Log

Date: 2026-05-02 JST
Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
Scope: iOS Source Profile catalog and synthesized Rec.709 conversion LUTs

## What changed

This work added two manual iOS Camera/Profile Source Profiles:

- `DJI D-Log`
- `Canon C-Log`

Both are implemented as synthesized input transforms, following the existing
V-Log / S-Log3 architecture:

`FilmtoneSourceProfileCatalog` -> `SourceProfileCurve` -> synthesized 33^3
RGB cube -> RGBA `CIColorCubeWithColorSpace` data -> export/preview input LUT
path -> sidecar provenance.

No App Store metadata, public release state, or portfolio code was intentionally
changed for this feature.

## Critical assumptions

The two new profiles are intentionally narrow:

- `DJI D-Log` means documented DJI D-Log / D-Gamut, using the DJI Zenmuse X9
  D-Log/D-Gamut white paper math. It is not D-Log M.
- `Canon C-Log` means original Canon Log using BT.709 gamut semantics. It is not
  Canon Log 3, and it is not Cinema Gamut.

These assumptions are product-quality decisions. D-Log M and C-Log3/Cinema
Gamut must be added as separate profiles because aliasing them to the profiles
above would create wrong color transforms for real footage.

## Files changed for the feature

Core Swift:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileSchema.swift`
  - Added `SourceProfileCurve.djiDLog = "dji-dlog"`.
  - Added `SourceProfileCurve.canonCLog = "canon-clog"`.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`
  - Added catalog row `built-in:source-profile.dji-dlog`.
  - Added catalog row `built-in:source-profile.canon-clog`.
  - Both have `detectionHint: nil`, so users must pick them manually.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
  - Added `dlogDecode`, `dgamutToRec709`, `dlogPixelToRec709`,
    `makeDlogToRec709Cube`.
  - Added `canonLogDecode`, `canonClogPixelToRec709`,
    `makeCanonClogToRec709Cube`.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
  - Routes `.djiDLog` and `.canonCLog` through synthesized cube generation.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift`
  - Added display labels for DJI D-Log and Canon C-Log.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
  - Updated retention-rule comments: D-Log/C-Log are sticky manual picks.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
  - Updated sidecar comments to include new curve raw values.

Fixture and verification:

- `apps/capacitor-film-lab-ios/scripts/swift/test-source-profile-math.swift`
  - Added D-Log and C-Log linearization + Macbeth/full-frame gates.
- `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/dji-dlog/`
  - New generator and committed generated fixture artifacts:
    `encode-ramp.py`, `linearization-ramp.json`, `macbeth-patches.json`,
    `source-encoded.png`, `expected-rec709.png`, `provenance.md`.
- `apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/canon-clog/`
  - Same structure as D-Log.
- `apps/capacitor-film-lab-ios/package.json`
  - Added `gen:fixtures:dlog`.
  - Added `gen:fixtures:clog`.

Docs and UI shell:

- `apps/capacitor-film-lab-ios/docs/source-profile-math/dji-dlog.md`
- `apps/capacitor-film-lab-ios/docs/source-profile-math/canon-clog.md`
- `apps/capacitor-film-lab-ios/src/features/editor/CameraProfilePill.tsx`
- `apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx`
- `apps/capacitor-film-lab-ios/src/lib/messages.ts`
- `apps/capacitor-film-lab-ios/src/presets/luts/README.md`
- `apps/capacitor-film-lab-ios/src/presets/signature.ts`
- `apps/capacitor-film-lab-ios/CLAUDE.md`

## Math details

### DJI D-Log

Source:
DJI, *White Paper on D-Log and D-Gamut of DJI Cinema Color System, DJI Zenmuse
X9 6K & 8K*, Rev.1.0, 2022.02.
https://dl.djicdn.com/downloads/DJI_Ronin_4D/X9_D_Log_D_Gamut_Whitepaper_I.pdf

Decode from encoded D-Log `V` to linear scene signal `L`:

```text
if V <= 0.14: L = (V - 0.0929) / 6.025
if V >  0.14: L = (10^(3.89616 * V - 2.27752) - 0.0108) / 0.9892
```

D-Gamut to Rec.709:

```text
[[ 1.6746, -0.5797, -0.0949],
 [-0.0981,  1.3340, -0.2359],
 [-0.0410, -0.2430,  1.2840]]
```

Pipeline:

```text
encoded DJI D-Log
-> dlogDecode
-> dgamutToRec709
-> filmtoneSdrShoulder
-> rec709Encode
-> Rec.709 SDR code value
```

### Canon C-Log

Sources:

- Canon, *Canon-Log Transfer Characteristic*, June 20, 2012.
  https://downloads.canon.com/CDLC/Canon-Log_Transfer_Characteristic_6-20-2012.pdf
- Colour Science Canon Log transfer implementation:
  https://colour.readthedocs.io/en/v0.3.12/_modules/colour/models/rgb/transfer_functions/canon_log.html

Decode from full-range normalized Canon Log `V` to linear scene signal `L`:

```text
pivot = 0.0730597
scale = 0.529136
gain  = 10.1596

if V <  pivot: L = -((10^((pivot - V) / scale) - 1) / gain) * 0.9
if V >= pivot: L =  ((10^((V - pivot) / scale) - 1) / gain) * 0.9
```

Pipeline:

```text
encoded Canon C-Log
-> canonLogDecode
-> filmtoneSdrShoulder
-> rec709Encode
-> Rec.709 SDR code value
```

No gamut matrix is applied for this original C-Log profile because this profile
is treated as BT.709 gamut. Canon Log 3 / Cinema Gamut must not reuse this path.

## Verification already run

Commands run from this chat:

```bash
bun run build
bun run verify:swift-contract
bun run verify:ios
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
bun run check:filmtone-copy
git diff --check
```

Results:

- `bun run build`: passed.
- `bun run verify:swift-contract`: passed.
- `bun run verify:ios`: passed.
- `xcodebuild ... CODE_SIGNING_ALLOWED=NO`: passed with pre-existing deprecation
  warnings around `AVMutableVideoComposition` and `CIColorKernel(source:)`.
- `bun run check:filmtone-copy`: passed.
- `git diff --check`: passed.

Source profile math gate output included:

```text
==> D-Log accuracy gate
    D-Log linearization max |Δ| = 0.000000 (budget 1e-3)
    D-Log Macbeth ΔE2000 max = 0.000 mean = 0.000 (budget 2.0/1.0)
    D-Log Macbeth full-frame max = 0.000 mean = 0.000 /255 (budget 2.0/0.5)
==> C-Log accuracy gate
    C-Log linearization max |Δ| = 0.000000 (budget 1e-3)
    C-Log Macbeth ΔE2000 max = 0.000 mean = 0.000 (budget 2.0/1.0)
    C-Log Macbeth full-frame max = 0.000 mean = 0.000 /255 (budget 2.0/0.5)
```

## Git / worktree notes

At the time this handoff was written, the repo was on `main`.

There were unrelated dirty changes visible before this source-profile work:

- fastlane metadata files
- fastlane screenshot README
- App Store screenshot delete/add set
- `apps/capacitor-film-lab-ios/.gitignore`
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/2026-05-02-ios-external-ssd-files-import-handoff-jst.md`

Those unrelated files were intentionally not part of the source-profile feature
scope. Do not revert them casually; treat them as user or prior-lane work unless
the next user explicitly asks otherwise.

## Next work: D-Log M

D-Log M must be treated as a separate product profile from DJI D-Log.

Reason:

- This chat found a public DJI D-Log/D-Gamut white paper with formal curve and
  gamut matrix.
- DJI D-Log M has many official conversion LUT downloads, but not the same
  clear public formal transform in the sources checked during this chat.
- Building D-Log M by reusing D-Log/D-Gamut would be a product-quality bug.

Recommended next-chat decision process:

1. Search current primary sources first: DJI support/download center, camera
   manuals, white papers, official LUT packages, and any documented D-Log M
   gamut/transfer statements.
2. If a formal transfer/gamut is available, implement it as synthesized math:
   new `SourceProfileCurve`, catalog row, math doc, fixture generator, fixture
   gate, and export route.
3. If only official LUTs are available, consider a bundled-cube path or an
   official-LUT-derived generated cube, but document licensing and provenance
   before committing.
4. Do not alias D-Log M to `dji-dlog`.
5. Keep `detectionHint: nil` unless iOS probe metadata can reliably identify
   D-Log M. Assume manual selection unless proven otherwise.

Likely files for D-Log M:

- `FilmtoneSourceProfileSchema.swift`
- `FilmtoneSourceProfileCatalog.swift`
- `FilmtoneSourceProfileMath.swift` or bundled cube resolution code
- `FilmtoneExportSession.swift`
- `FilmtoneStrings.swift`
- `test-source-profile-math.swift`
- `Tests/Fixtures/source-profile/dji-dlog-m/`
- `docs/source-profile-math/dji-dlog-m.md`
- TS copy/menu types if the web shell still exposes CameraProfile entries.

## Next work: Canon Log 3 / Cinema Gamut

Canon Log 3 / Cinema Gamut must be separate from `canon-clog`.

Reason:

- Canon Log original and Canon Log 3 have different transfer curves.
- Cinema Gamut has different primaries and requires a gamut matrix to Rec.709.
- Canon cameras can expose multiple Canon Log / gamut permutations. The profile
  name should be explicit enough that a user does not apply the wrong transform.

Recommended next profile name:

- UI label: `Canon Log 3 / Cinema Gamut`
- Catalog id: `built-in:source-profile.canon-log3-cinema-gamut`
- Curve raw value: `canon-log3-cinema-gamut`
- Fixture directory: `Tests/Fixtures/source-profile/canon-log3-cinema-gamut/`

Suggested math sources to verify in the next chat:

- Canon EOS / Cinema EOS manuals for the Gamma/Color Space pairing.
- Canon or OCIO/ACES references for Canon Log 3 transfer.
- Canon Extended Color Gamut / Cinema Gamut references.
- Colour Science / Antler Post can be used as implementation cross-checks, but
  prefer Canon primary sources where available.

Expected shape:

```text
encoded Canon Log 3
-> canonLog3Decode
-> cinemaGamutToRec709
-> filmtoneSdrShoulder
-> rec709Encode
-> Rec.709 SDR code value
```

Do not silently reuse `canonLogDecode` or skip the Cinema Gamut matrix.

## Verification expectation for the next chat

For D-Log M and/or Canon Log 3 / Cinema Gamut, the next chat should run at
minimum:

```bash
bun run --cwd apps/capacitor-film-lab-ios build
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
bun run verify:ios
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
git diff --check
```

If copy changes are made:

```bash
bun run check:filmtone-copy
```

## Highest-precision prompt for the next chat

```text
You are working in:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Task:
Continue Filmtone iOS Source Profile work by adding D-Log M and/or Canon Log 3
/ Cinema Gamut Rec.709 conversion support. Product color quality is the priority.
Do not add label-only profiles.

Start rules:
1. Read AGENTS.md.
2. Run git status --short --branch.
3. Open apps/capacitor-film-lab-ios/CLAUDE.md.
4. Open this handoff:
   docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/2026-05-02-ios-source-profile-dlog-clog-handoff-jst.md
5. Then inspect only the current Source Profile surfaces:
   - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileSchema.swift
   - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift
   - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift
   - apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift
   - apps/capacitor-film-lab-ios/scripts/swift/test-source-profile-math.swift
   - apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/
   - apps/capacitor-film-lab-ios/docs/source-profile-math/

Important current truth:
- The previous chat added DJI D-Log and Canon C-Log original as manual built-in
  synthesized profiles.
- DJI D-Log means documented DJI D-Log / D-Gamut from the Zenmuse X9 white
  paper. It is not D-Log M.
- Canon C-Log means Canon Log original in BT.709 gamut. It is not Canon Log 3
  and not Cinema Gamut.
- Do not alias D-Log M to dji-dlog.
- Do not alias Canon Log 3 / Cinema Gamut to canon-clog.
- Keep manual profiles detectionHint nil unless reliable iOS metadata detection
  is proven from source/probe code.

Research requirements:
- For D-Log M, verify current DJI primary sources or official LUT packages
  before choosing synthesized math vs bundled/generated cube. If no formal
  public transfer/gamut exists, do not invent one from memory.
- For Canon Log 3 / Cinema Gamut, verify Canon primary docs where possible and
  cross-check with Colour Science / OCIO / Antler Post. Implement a real Log3
  transfer and Cinema Gamut to Rec.709 matrix.

Implementation expectation:
- Add new SourceProfileCurve raw values and catalog IDs.
- Add localized labels.
- Add math docs and fixture generators.
- Add fixture JSON/PNG/provenance artifacts.
- Extend scripts/swift/test-source-profile-math.swift so fixture drift is a
  hard gate.
- Route new curves in FilmtoneExportSession.makeSynthesizedInputLut.
- Update sidecar comments/docs and relevant TS menu/copy surfaces.

Verification expectation:
Run:
bun run --cwd apps/capacitor-film-lab-ios build
bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract
bun run verify:ios
xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
git diff --check

If UI/app copy changes, also run:
bun run check:filmtone-copy

Dirty worktree warning:
This repo can contain unrelated user changes, especially fastlane metadata and
screenshots. Do not revert or commit unrelated changes unless explicitly asked.
```
