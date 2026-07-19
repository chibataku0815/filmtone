# MON-2 Resolve Runtime Verification Runbook

Date: 2026-07-19 JST
Owner-gated: yes (admin install + a Resolve session + watermark visual judgment)

The license-math side of MON-2 is already verified statically:
`scripts/license/parity/run.sh` cross-checks the C++ `LicenseStore` against the
TS `core.ts` reference — **17/17 PASS**, including the canonical-parity crown
jewel and non-ASCII / JSON-escape / emoji-surrogate names. This runbook closes
the three items that can only be confirmed inside DaVinci Resolve.

## 0. Prerequisites

```sh
# 1. Build the bundle (either worktree; identical LicenseStore/watermark source):
make -C apps/filmtone-resolve-ofx        # -> build/Filmtone.ofx.bundle

# 2. Generate the test license files:
bun run scripts/license/parity/gen_license_files.ts /tmp/filmtone-licenses
#    -> full.license  trial.license  trial-expired.license  tampered.license
```

Note on identity: the plugin currently registers under the generated
**compatibility** OFX id `com.chibatakumi.filmtone.finish` with display name
**Filmtone** (see monetization/progress.md 改訂 15 / the integration review
branch). That is expected; unifying to `.resolve` is a separate cosmetic
decision.

## 1. Install (choose one)

The build target is `apps/filmtone-resolve-ofx/build/Filmtone.ofx.bundle`.

- **Admin install (canonical):** `/Library/OFX/Plugins` is root-owned, so this
  needs `sudo`. Remove the old `FilmtoneFinish.ofx.bundle` first to avoid two
  Filmtone entries.
  ```sh
  sudo rm -rf "/Library/OFX/Plugins/FilmtoneFinish.ofx.bundle"
  sudo cp -R apps/filmtone-resolve-ofx/build/Filmtone.ofx.bundle "/Library/OFX/Plugins/"
  ```
- **No-admin (if this Resolve build honors it):** set `OFX_PLUGIN_PATH` to a
  user dir holding the bundle and launch Resolve from that environment. Verify
  Resolve enumerates the effect; if not, use the admin install.

Restart Resolve after installing.

## 2. Apply the effect

Open a disposable project on a real (ideally ProRes) clip, add a Color-page
node, and add **OFX: Filmtone**. Confirm the param panel shows the module groups
and a read-only **License > Status** label.

## 3. License state matrix

License path: `~/Library/Application Support/Filmtone/Filmtone.license`.
For each row: copy the file (or remove it), **re-render the frame** (license is
read on render; the Status label refreshes on panel re-display), and observe.

| Test file placed | Expect image | Expect License > Status |
|---|---|---|
| (none — remove the file) | **watermark** | `Trial mode (watermarked)` |
| `full.license` | **clean** | `Licensed to Owner Verification` |
| `trial.license` | **clean** | `Trial — expires YYYY-MM-DD` |
| `trial-expired.license` | **watermark** | `Trial mode (watermarked)` |
| `tampered.license` | **watermark** | `Trial mode (watermarked)` |

```sh
mkdir -p ~/Library/Application\ Support/Filmtone
cp /tmp/filmtone-licenses/full.license ~/Library/Application\ Support/Filmtone/Filmtone.license
# ...swap per row; remove the file for the "none" row.
```

## 4. Determinism + GPU watermark-ordering (the one open technical risk)

The watermark reads the module output in a separate Metal command buffer; if
Resolve's output buffer is untracked, it could race the module write and flicker
only in the watermark region. Detect it deterministically:

- In a watermark state (e.g. no license), export the **same** frame **twice**
  and compare raw pixels:
  ```sh
  # export frame twice to a lossless format (e.g. 16-bit PNG / EXR), then:
  md5 export_a.png export_b.png     # MUST be identical
  ```
- Also scrub away and back to the frame, re-export, compare again.

If the two exports differ **only in the watermark band**, that is the ordering
race. Remedy (ready, not yet applied): redirect the final module pass to a
hazard-tracked private intermediate and make WatermarkPass read that
intermediate (source->output) instead of reading the host output in place, so
the read is auto-synchronized. Apply only if a race is observed.

## 5. Identity invariant (licensed path)

With `full.license` placed and **every module off**, a disabled-vs-enabled export
must be **bit-exact identical** (same raw MD5) — the licensed identity invariant.

## 6. Watermark visual (owner judgment)

The default is a low-opacity, mid-gray, diagonally tiled "FILMTONE TRIAL" text —
an intentional placeholder. Judge wording / size / opacity / placement. All are
tunable constants at the top of
`apps/filmtone-resolve-ofx/Sources/License/WatermarkPass.mm`
(`kOpacity`, `kColorR/G/B`, `kRotationDegrees`, `kTexelCanonicalSize`,
`kTileGapCanonicalX/Y`). Provide 2-3 preferred candidates and they can be set.

## 7. Record

Record pass/fail per section in `workstreams/progress/license.md`. On full pass,
MON-2 moves from `Review` to `Accepted`; the remaining launch path is MON-5
(signing/notarization) then MON-6.
