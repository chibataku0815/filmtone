# Filmtone iOS Phase 0 Device Check

Use this app path only:

- `apps/capacitor-film-lab-ios`

Use this workspace only:

- `apps/capacitor-film-lab-ios/ios/App/App.xcworkspace`

## Formal 60s benchmark run

1. Connect the same successful `iPhone 15+` if available.
2. From the repo root, run:
   `bun run open:ios-phase0`
3. In Xcode, select the connected device and run the app.
4. Inside the app, select one fixed exact `60-second` segment trimmed from the previously successful `4m29s` source clip.
5. Use:
   - `preset + creative LUT`
6. Complete one flow:
   `pick source -> preview -> export -> save to Photos`
7. Review the exported file itself:
   - first section
   - middle section
   - final section
8. This run is the formal `60s <= 2.5x realtime` gate for the baseline device.
   Treat `<= 2.0x realtime` as strong-go evidence.

## Report back in this chat

Use the `Clip` field to record which fixed 60-second segment you ran.

Copy these fields:

```text
Device:
iOS:
Clip:
Source codec:
Source resolution:
Source duration:
Settings profile:
Import:
Export:
Save to Photos:
Elapsed:
Realtime ratio:
Output resolution / fps:
Output file size:
Thermal state:
Memory warnings:
Black frame:
Visual floor:
Errors:
```

## Success means

- app launches on device
- source can be selected
- export completes
- save to Photos completes
- no black frames
- no permission dead-end
- exported file clears first / middle / final spot checks

## If it fails

Report the exact failing step and any visible error text.
