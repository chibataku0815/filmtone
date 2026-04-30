# Filmtone Connect for DaVinci — Overall Product Plan

- **作成日**: 2026-04-30 JST
- **目的**: `Filmtone Connect for DaVinci` を DaVinci v0 spike から iOS package export、製品 claim、将来 SKU まで一貫して進めるための全体計画書
- **対象 repo**: `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
- **iOS app**: `apps/capacitor-film-lab-ios`
- **現在地点**: DaVinci v0 import spike は実機 smoke 済み。次は iOS real package export。

---

## 1. Product Position

Filmtone Connect for DaVinci は、Filmtone iOS を DaVinci の代替にする機能ではない。

正しい位置付け:

```text
Filmtone iOS
  = iPhone 上で pre-grade / physical look / source provenance を作る

DaVinci Resolve
  = finishing / edit / color refinement を行う

Filmtone Connect for DaVinci
  = その間を media + sidecar + LUT + reference でつなぐ bridge
```

最初の claim:

```text
Pre-grade on iPhone. Finish in DaVinci.
```

日本語:

```text
iPhone で下地を、DaVinci で仕上げを。
```

非 claim:

- DaVinci 上で Filmtone の全処理を完全再現できる。
- Sidecar だけで見た目が再現できる。
- 3D LUT だけで depth / ray-angle optics / grain / motion blur / halation spread が完全再現できる。
- Filmtone がモバイル DaVinci になる。

---

## 2. Product Thesis

PeekLut などの競合が「iPhone / iPad 上の DaVinci 代替」を取りに来るなら、Filmtone は機能数競争をしない。

Filmtone の差別化は以下に置く。

- dual-lane color thinking: Source Profile / Film Look
- sidecar data contract
- source color metadata / HDR / Log / P3 policy
- baked physical look: glow / halation / optics / depth / grain
- reference still による visual ground truth
- DaVinci finishing へ渡せる provenance

価値の中心:

```text
Filmtone は「iPhone で作った下地」を、DaVinci の編集可能な finishing workflow に持ち込む。
```

---

## 3. Current Verified State

### 3.1 DaVinci v0

Commit:

```text
9a1c43e8 feat(filmtone-ios): add DaVinci connect v0 spike
```

Script:

```text
apps/capacitor-film-lab-ios/scripts/davinci/filmtone_connect_import_package.lua
```

Verified knowledge:

```text
docs/filmtone/ios/filmtone-connect-davinci-v0-spike-verified-2026-04-30-jst.md
```

Verified Resolve:

```text
DaVinci Resolve 20.3.2.9
```

実機 smoke 成功:

```text
SMOKE_NODE1_LUT=Filmtone Connect/combined-color.cube
SMOKE_TIMELINE_MARKERS=1
SMOKE_FILMTONE_NOTE_FOUND=true
SMOKE_GALLERY_STILLS=2
```

### 3.2 Critical Technical Fact

DaVinci は package-local `.cube` absolute path を安定して `SetLUT` できなかった。

安定経路:

```text
copy .cube to:
  /Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/Filmtone Connect/

Project:RefreshLUTList()
Graph:SetLUT(1, "Filmtone Connect/combined-color.cube")
```

この事実を後続設計の前提にする。

---

## 4. Target Architecture

### 4.1 Data Flow

```text
Filmtone iOS export
  -> media
  -> sidecar JSON
  -> combined-color.cube
  -> reference-after.jpg
  -> share / Files / AirDrop
  -> DaVinci Workspace Script
  -> Media Pool
  -> Timeline item
  -> Color node 1 LUT
  -> Marker note
  -> Gallery reference still
```

### 4.2 Package Layout

Minimum package:

```text
FilmtoneExport/
  media.mov
  media.mov.filmtone-ios-export-session-v1.json
  combined-color.cube
  reference-after.jpg
```

Future package:

```text
FilmtoneExport/
  media.mov
  media.mov.filmtone-ios-export-session-v1.json
  source-transform.cube
  film-look.cube
  combined-color.cube
  reference-before.jpg
  reference-after.jpg
```

### 4.3 Sidecar Role

Sidecar is:

- data contract
- manifest
- export receipt
- provenance carrier

Sidecar is not:

- archive
- LUT payload container
- full visual reproduction engine

### 4.4 Sidecar Package Block

Additive v1 field:

```json
{
  "package": {
    "layout": "filmtone-connect-package-v1",
    "mediaFilename": "media.mov",
    "referenceAfterFilename": "reference-after.jpg",
    "luts": {
      "combinedColor": "combined-color.cube"
    }
  }
}
```

Future additive extension:

```json
{
  "package": {
    "layout": "filmtone-connect-package-v1",
    "mediaFilename": "media.mov",
    "referenceBeforeFilename": "reference-before.jpg",
    "referenceAfterFilename": "reference-after.jpg",
    "luts": {
      "sourceTransform": "source-transform.cube",
      "filmLook": "film-look.cube",
      "combinedColor": "combined-color.cube"
    }
  }
}
```

Schema rule:

- Additive optional field: keep `filmtone-ios-export-session-v1`.
- Field rename / type change / semantic change: create v2.
- LUT data array must remain outside sidecar.

---

## 5. Roadmap

### Phase 0 — DaVinci Intake Proof

Status: done.

Goal:

- Prove DaVinci can read package, import media, apply LUT, preserve marker note, import reference.

Delivered:

- Lua Workspace Script.
- Embedded JSON parser.
- LUT staging into Resolve LUT tree.
- Marker note with baked effects and non-claim.
- Gallery still import.
- Real Resolve 20.3.2.9 smoke.

### Phase 1 — iOS Real Package Export

Status: next.

Goal:

- Filmtone iOS produces a package that DaVinci v0 script can consume.

Required outputs:

- exported media
- sidecar with additive `package` block
- `combined-color.cube`
- `reference-after.jpg`

Success:

```text
iOS-generated package -> DaVinci script -> node 1 LUT + marker note + Gallery still
```

Do not start with:

- UI polish
- zip
- DRX
- PowerGrade
- Source/Film multiple nodes

### Phase 1.1 — Package Handoff UX

Status: after Phase 1 works.

Goal:

- Make the package handoff usable from Files / AirDrop / share sheet.

Potential UX:

- `Send to DaVinci`
- `Export Package`
- `Send to NLE`

Implementation preference:

1. Multiple file URLs in share sheet.
2. Folder/package if iOS UX supports it cleanly.
3. Zip only if multi-file share is poor.

Acceptance:

- User can move package from iPhone to Mac without losing JSON/LUT/reference.
- Photos save remains media-only and is not positioned as pro bridge.

### Phase 2 — Dual-Lane Resolve Workflow

Status: future.

Goal:

- Preserve Filmtone's Source Profile / Film Look concept in DaVinci.

Potential output:

```text
source-transform.cube
film-look.cube
combined-color.cube
```

Potential Resolve behavior:

- Node 1: Filmtone Source Transform
- Node 2: Filmtone Film Look
- Node 3: manual finishing

Important:

- DaVinci scripting README confirms `Graph:SetLUT`, not stable node creation / node label authoring in the current inspected API.
- Multi-node workflow may need DRX / PowerGrade template instead of raw node creation.

### Phase 3 — DRX / PowerGrade Candidate

Status: research after Phase 2.

Goal:

- Package a richer DaVinci grade structure.

Candidate:

- Generate or ship a template DRX / PowerGrade.
- Apply via `ApplyGradeFromDRX`.
- Then apply / replace LUT references.

Risks:

- DRX generation may not be stable/documented.
- User's Resolve version / Free vs Studio / LUT path settings can vary.

### Phase 4 — DCTL / OpenFX Approximation

Status: later, paid SKU candidate.

Goal:

- Approximate some Filmtone transforms natively in DaVinci.

Allowed scope:

- color-only or print/tone transforms
- carefully documented approximations

Do not promise:

- depth-aware optics parity
- temporal motion blur parity
- exact grain / halation spread parity
- full Filmtone shader pipeline parity

---

## 6. Quality Gates

### Gate A — Package Contract

Must pass:

- package contains all minimum files
- sidecar `kind/schema/version` valid
- sidecar `package.layout` valid
- package filenames are relative, not app-container-only URIs
- sidecar still omits LUT `data` arrays
- package can be parsed by DaVinci script `--dry-run`

### Gate B — Color Bridge

Must pass:

- generated `.cube` is syntactically valid
- DaVinci can discover staged LUT
- node 1 reports `Filmtone Connect/combined-color.cube`
- visible output is plausible against Filmtone export/reference

### Gate C — Baked Effect Provenance

Must pass:

- marker note lists baked glow / halation / grain / optics params
- depth block is present and explicit
- mezzanine block is present and explicit
- non-claim text remains present
- `reference-after.jpg` is imported or referenced

### Gate D — Handoff UX

Must pass:

- package survives Files / AirDrop / share path
- Mac side receives all package files
- DaVinci script can consume received package without editing JSON

### Gate E — Release Claim Safety

Must pass before public copy:

- no "complete recreation" wording
- no "DaVinci replacement" wording
- no "all Filmtone effects editable in Resolve" wording
- claim stays pre-grade / handoff / finish

---

## 7. Implementation Principles

### 7.1 Core First

Implementation order:

1. Generate `combined-color.cube`.
2. Generate `reference-after.jpg`.
3. Add sidecar package block.
4. Share all package files.
5. Run DaVinci import.
6. Only then improve UI naming / package UX.

### 7.2 No Silent Degradation

Do not silently omit required package files.

Acceptable:

- explicit error: `combined-color.cube generation failed`
- explicit package missing report in DaVinci script
- marker note saying a reference is absent

Not acceptable:

- package export says success but lacks sidecar/LUT/reference
- fallback to media-only share while presenting as DaVinci package
- applying no LUT while claiming Connect success

### 7.3 Keep Photos Separate

Photos save remains media-only.

DaVinci bridge must use:

- Files
- AirDrop
- share package
- future zip/package bundle

Do not claim Photos contains sidecar or LUT.

---

## 8. Technical Risks

### LUT Generation Scope

Risk:

- `combined-color.cube` may be interpreted as "complete Filmtone look".

Control:

- name it "combined color" and keep non-claim explicit.
- marker note says optics / grain / depth are baked/reference provenance.

### Color Parity

Risk:

- LUT generated from app math may not match export pipeline if color spaces / tone map differ.

Control:

- compare against `reference-after.jpg`.
- include output color profile in sidecar.
- use rec709 SDR contract for v1.

### Resolve LUT Discovery

Risk:

- Resolve does not discover package-local LUT.

Control:

- stage into Resolve LUT tree.
- refresh LUT list.
- use relative path `Filmtone Connect/combined-color.cube`.

### iOS Share UX

Risk:

- multiple files are awkward or lost by target app.

Control:

- first validate Files / AirDrop.
- consider zip only if multi-file share fails.

### Dirty Worktree

Risk:

- existing uncommitted Swift work conflicts with package export changes.

Control:

- inspect before editing.
- do not revert user changes.
- stage only files belonging to the task.

---

## 9. Acceptance Milestones

### 2-Day Spike

Outcome:

- local iOS/package generation code path exists
- generated package passes DaVinci script `--dry-run`
- generated `.cube` is valid
- sidecar package block present

### 1-Week Product Spike

Outcome:

- package can be exported/shared from iOS build
- package can be moved to Mac
- DaVinci import succeeds on real generated package
- reference still validates visual intent
- no major claim boundary ambiguity remains

### Release Candidate

Outcome:

- package UX named and discoverable
- error states clear
- contract tests exist
- real device export tested
- DaVinci import tested
- App Store copy uses safe claim only

---

## 10. Next Concrete Task

Implement **Phase 1: iOS Real Package Export**.

Minimum deliverable:

```text
One real Filmtone iOS export produces:
  media
  media.filmtone-ios-export-session-v1.json
  combined-color.cube
  reference-after.jpg

Then DaVinci v0 script imports it successfully.
```

Suggested first implementation focus:

- Add package metadata types to sidecar builder.
- Add `.cube` serializer/generator for combined color.
- Add reference-after export function.
- Add share path that includes package files.
- Add contract tests that sidecar package block exists and no LUT arrays leak into JSON.

---

## 11. Related Documents

- `docs/filmtone/ios/filmtone-connect-davinci-real-package-export-handoff-2026-04-30-jst.md`
- `docs/filmtone/ios/filmtone-connect-davinci-v0-spike-verified-2026-04-30-jst.md`
- `docs/filmtone/ios/filmtone-connect-for-davinci-feasibility-handoff-2026-04-29-jst.md`
- `docs/filmtone/ios/filmtone-ios-peeklut-positioning-pivot-handoff-2026-04-29-jst.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
