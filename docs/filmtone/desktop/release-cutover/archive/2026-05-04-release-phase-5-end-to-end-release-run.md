# Release-cutover Phase 5 — M6-6 end-to-end release run

Date opened: 2026-05-04 JST
Closed: 2026-05-04 JST (same day)

## Goal

Run the full release pipeline end-to-end for `0.1.0` and produce a
distribution-ready, notarized + stapled `FilmtoneDesktop.app` and
`FilmtoneDesktop-0.1.0.dmg`.

This closes M6-6 (which Phase 4 left at "all archive + exportArchive
prerequisites verified, only `ASC_ISSUER_ID` env missing").

## Scope

In-scope:

- Run `scripts/release-macos.sh` with full ASC env (notarytool submit + staple).
- Run `scripts/package-dmg.sh 0.1.0 <output_dir>` against the notarized .app.
- Verify the resulting .app and DMG with `codesign -dvvv` and `spctl --assess`.
- Capture artifact hashes (sha256 DMG, CDHash .app) for audit.
- Update `release-cutover/README.md` milestone table M6-6 row + add Phase 5
  close summary.
- Append a Phase 5 entry to `native-desktop-v2/strategy.md` Completion Log.

Out of scope (handed back to user, CLAUDE.md §9 / §7 boundary):

- `git push` (commit override is bounded to commit-only in this lane).
- `git tag v0.1.0` (release tag).
- Portfolio `vendor/filmtone` submodule bump (different repo, §7 procedure).
- Distribution channel decision (GitHub Releases / direct download / web).
- Sparkle auto-update — explicitly out-of-scope per release-cutover README L31.

## Run environment

ASC env sourced from `apps/capacitor-film-lab-ios/.env.local` (iOS Fastfile
parity, README L52-54):

```
ASC_KEY_ID     = TM2BK9269B
ASC_ISSUER_ID  = bac140b6-7b35-44ca-b9e1-82b037e08e69
ASC_KEY_PATH   = /Users/chibatakumi/.appstoreconnect/private_keys/AuthKey_TM2BK9269B.p8
```

`.p8` key file: 257 bytes, mode 0600, owner chibatakumi (correct for ECC
private key on this account).

Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch:  `feature/native-desktop-plan`
Head before run: `e619e0f5` (`docs(release-cutover): Phase 4 — pre-flight readiness audit`)

## Run 1 — `scripts/release-macos.sh`

```
==> Version: 0.1.0
==> Output:  apps/filmtone-desktop-macos/build/release/0.1.0
==> 1/6 archive (Release, Developer ID)            ** ARCHIVE SUCCEEDED **
==> 2/6 exportArchive (developer-id)               ** EXPORT SUCCEEDED **
==> 3/6 zip for notarytool
==> 4/6 notarytool submit --wait                   (Apple notary 受理)
==> 5/6 stapler staple                             The staple and validate action worked!
==> 6/6 spctl --assess
        FilmtoneDesktop.app: accepted
        source=Notarized Developer ID
==> OK: apps/filmtone-desktop-macos/build/release/0.1.0/FilmtoneDesktop.app
        (notarized + stapled, Team C3G77H8NM6)
        Bundle ID: co.fores-tone.filmtone.desktop
```

Submission record: `notarize-submission.json`.

## Run 2 — `scripts/package-dmg.sh 0.1.0 ...`

```
==> Version:    0.1.0
==> Source app: ...build/release/0.1.0/FilmtoneDesktop.app
==> Target DMG: ...build/release/0.1.0/FilmtoneDesktop-0.1.0.dmg
==> 1/6 stage .app + Applications symlink
==> 2/6 hdiutil create
==> 3/6 codesign DMG
==> 4/6 notarytool submit DMG --wait               (Apple notary 受理)
==> 5/6 stapler staple DMG                         The staple and validate action worked!
==> 6/6 spctl --assess --type open
        FilmtoneDesktop-0.1.0.dmg: accepted
        source=Notarized Developer ID
==> OK: ...FilmtoneDesktop-0.1.0.dmg (notarized + stapled, distribution-ready)
        Size: 6.9 MB
```

Submission record: `notarize-dmg-submission.json`.

## Final codesign (.app post-staple)

```
Executable=...FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop
Identifier=co.fores-tone.filmtone.desktop
Format=app bundle with Mach-O universal (x86_64 arm64)
CodeDirectory v=20500 size=1418 flags=0x10000(runtime) hashes=33+7 location=embedded
Hash type=sha256 size=32
CandidateCDHash sha256=9f28ad58e075172222464a51505b29ed74ab4049
CDHash=9f28ad58e075172222464a51505b29ed74ab4049
Authority=Developer ID Application: takumi chiba (C3G77H8NM6)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
Timestamp=May 4, 2026 at 20:33:30
Notarization Ticket=stapled
Info.plist entries=21
TeamIdentifier=C3G77H8NM6
Runtime Version=26.4.0
Sealed Resources version=2 rules=13 files=2
```

Key signals:

- `flags=0x10000(runtime)` ✓ Hardened Runtime active
- Full Apple Authority chain ✓
- Secure timestamp ✓
- `Notarization Ticket=stapled` ✓ (offline Gatekeeper success)
- Universal x86_64 + arm64 ✓
- TeamID matches `C3G77H8NM6`

## Artifact hashes

```
sha256 (DMG) = cc4a2666e4cc4524acb67bf3097da78b18de7806cea71c72acda7adf20cd3398
CDHash (.app) = 9f28ad58e075172222464a51505b29ed74ab4049
```

## Done conditions

- [x] `scripts/release-macos.sh` 6/6 pass
- [x] `scripts/package-dmg.sh` 6/6 pass
- [x] `.app` `Notarization Ticket=stapled`
- [x] DMG `spctl --assess --type open` accepted
- [x] Artifacts on disk under `apps/filmtone-desktop-macos/build/release/0.1.0/`
- [x] M6 milestone table M6-6 row updated to Done
- [x] strategy.md Completion Log Phase 5 entry appended

## Hand-back to user

Remaining steps (CLAUDE.md §9 user 委任、§7 portfolio bump 手順):

```bash
# 1. push the release-cutover doc commits + lane state
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
git push origin feature/native-desktop-plan   # or merge to main first

# 2. tag the release
git tag -a v0.1.0 -m "Filmtone Desktop 0.1.0"
git push origin v0.1.0

# 3. portfolio submodule bump (different repo)
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
git submodule update --remote vendor/filmtone
git add vendor/filmtone
git commit -m "chore(filmtone): bump submodule to 0.1.0"
git push   # vercel deploy

# 4. distribute the DMG via chosen channel (GitHub Releases / direct / web)
```

The `.app` and DMG under
`apps/filmtone-desktop-macos/build/release/0.1.0/` are gitignored build
artifacts; they are not committed. The DMG is the distribution artifact
attached out-of-band.

## Lessons / non-obvious

1. `ASC_ISSUER_ID` was already configured in `apps/capacitor-film-lab-ios
   /.env.local` from iOS lane setup. The release-cutover README L52-54
   ("iOS Fastfile が ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_CONTENT or
   ASC_KEY_PATH 経由で notarize する pattern を採用済 → macOS lane も同 env
   で流用") was load-bearing — flowing through it removed the only
   remaining environmental blocker.
2. `MARKETING_VERSION = 0.1.0` is pinned in pbxproj; the script ran 0.1.0
   directly. The Phase 1 plan's "0.1.0-rc1 dry-run" became unnecessary
   because the substance verifications (Phase 4 pre-flight + Phase 5 actual
   run) covered the same ground without a separate rc tag.
3. Both pipelines are deterministic at the script level: 6 step + early
   `preflight_signing_cert` fail-fast. Both runs hit zero failures, which
   matches Phase 4's prediction that "user's first `scripts/release-macos.sh`
   run is guaranteed to clear archive + exportArchive; failure modes can
   only originate downstream in notarytool submit or post-notarize spctl"
   — neither downstream failure occurred either.
