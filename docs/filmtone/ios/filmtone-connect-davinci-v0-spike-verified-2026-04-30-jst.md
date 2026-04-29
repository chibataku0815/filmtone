# Filmtone Connect for DaVinci v0 Spike — Verified Knowledge

- Date: 2026-04-30 JST
- Scope: DaVinci-side v0 import spike only
- Repo: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- Script: `apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua`
- Verified Resolve: DaVinci Resolve `20.3.2.9`

## Result

The core bridge is feasible:

```text
Filmtone package
  media.mov
  media.mov.filmtone-ios-export-session-v1.json
  combined-color.cube
  reference-after.jpg

DaVinci Resolve
  import media
  create/append timeline item
  apply combined-color.cube to node 1
  write Filmtone marker note
  import reference still into Gallery
```

Verified smoke output:

```text
SMOKE_NODE1_LUT=Filmtone Connect/combined-color.cube
SMOKE_TIMELINE_MARKERS=1
SMOKE_FILMTONE_NOTE_FOUND=true
SMOKE_GALLERY_STILLS=2
```

## Critical Finding

`Graph:SetLUT(1, absolutePackageCubePath)` is not reliable for package-local `.cube`
files, even though the Resolve scripting README says absolute paths are accepted.

The stable path is:

1. Copy the `.cube` into Resolve's LUT tree:

   ```text
   /Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/Filmtone Connect/
   ```

2. Call `Project:RefreshLUTList()`.
3. Apply the relative LUT path:

   ```text
   Filmtone Connect/combined-color.cube
   ```

This is now what the v0 script does.

## How To Run

Install path used for local manual testing:

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/Filmtone Connect/Import Filmtone Package.lua
```

The local install is a symlink to the repo script. After installing, restart
Resolve or re-scan scripts, then run:

```text
Workspace > Scripts > Filmtone Connect > Import Filmtone Package
```

The script resolves the package folder in this order:

1. `--package /path/to/package`
2. first positional argument
3. `FILMTONE_CONNECT_PACKAGE`
4. macOS folder picker
5. console prompt

Dry-run parser check:

```bash
"/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript" \
  apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua \
  --dry-run \
  --package /path/to/FilmtoneExport
```

## Product Boundary

The v0 claim is valid:

```text
Pre-grade on iPhone. Finish in DaVinci.
```

The v0 non-claim is equally important:

```text
The LUT does not recreate depth, ray-angle optics, grain, motion blur,
or halation spread. Those travel as baked media + reference still +
sidecar provenance.
```

Marker notes intentionally preserve:

- preset and output color contract
- LUT lane refs and intensities
- baked glow / halation / grain / optics params
- depth and mezzanine state
- reference still path

## Next Implementation Step

Do not start with iOS package UI.

The next product-quality step is a real Filmtone package export spike that
produces:

- package-relative sidecar fields
- `combined-color.cube`
- `reference-after.jpg`
- media + sidecar + LUT + reference share path

Only after that should separated `source-transform.cube` / `film-look.cube`,
DRX, PowerGrade, DCTL, or OpenFX be considered.
