# Filmtone Studio App Review Resubmission - 2026-05-27

## Summary

Apple rejected iPad app submission `b33bde78-93bc-4841-83f7-cf502dcf5da7`
for Guideline 5.2.5 because the app name used the Apple product term `iPad`.

Resolution:

- Renamed the App Store metadata app name to `Filmtone Studio` for `ja`,
  `en-US`, and `en-GB`.
- Removed remaining unnecessary Apple product/service terms from the generated
  iPad App Store metadata and review notes.
- Kept the corrected app-in-use screenshots unchanged.
- Resubmitted version `1.0 (2)` on 2026-05-27 at 10:40 JST.

## Current ASC State

API verification after resubmission:

- Review submission state: `WAITING_FOR_REVIEW`
- App version state: `WAITING_FOR_REVIEW`
- App Store state: `WAITING_FOR_REVIEW`
- Submitted date: `2026-05-27T01:40:43.471Z`
- Submitted by: API user

The App Store Connect UI also showed the submission as `審査待ち`.

## Verification

- `bun run check:filmtone-copy` passed.
- `git diff --check` passed.
- Release truth scripts were run before reporting App Store state:
  - `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh`
  - `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
- ASC metadata audit found no remaining generated iPad metadata hits for
  `Filmtone Canvas`, `Canvas`, `iPad`, `iPhone`, `Apple`, `App Store`, `Mac`,
  `iOS`, `Photos`, or `Files`.

## Copy / History Impact

Copy / History Impact: App Store metadata only. No implementation-history
change.

Article Opportunity: No story.

Change-History Opportunity: No change-history entry needed.

## Remaining Risk

Apple could still object to product terms inside screenshots, app UI, bundle
identifiers, or other non-editable system surfaces, but public App Store
metadata and review notes were scrubbed for the cited issue before resubmission.

## 2026-05-28 Distribution Restore

After approval, App Store Connect showed the version as `配信準備完了` but also
showed that the app had been removed from App Store distribution. The issue was
the app availability relationship: all territory availability records needed to
be enabled.

Resolution:

- Updated all 175 App Store territories to `available: true` through the App
  Store Connect API.
- Confirmed `availableInNewTerritories: true`.
- Confirmed App Store Connect no longer shows the removal warning on the
  version page.
- Confirmed App Store version `1.0` is `READY_FOR_SALE`.
- Confirmed public lookup returns `Filmtone Studio`, bundle
  `com.chibatakumi.film.lab.ipad`, version `1.0`, price `無料`, and URL
  `https://apps.apple.com/jp/app/filmtone-studio/id6771818125?uo=4`.

Copy / History Impact: No copy/history impact. Distribution settings only.

Article Opportunity: No story.

Change-History Opportunity: No change-history entry needed.
