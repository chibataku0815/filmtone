# Deterministic Film Damage as an OFX Plugin for DaVinci Resolve

Status: candidate draft (pre-launch). Do not make any public state, price,
launch-date, or compatibility claim until owner approval is confirmed in the
monetization progress.md (the coordinator-owned truth). The iOS / Desktop
truth scripts do not apply to this product.

Publication switch:

- Before launch: keep `upcoming`, `at launch`. Avoid `released`, `now
  available`, `we shipped`.
- After launch (owner-approved): finalize as an implementation note and replace
  price, launch date, and purchase links with confirmed values.

TOC policy: Hashnode generates a table of contents from headings when it is
enabled in Article Settings. Do not add a manual TOC. Keep H2s self-contained.

---

Filmtone for DaVinci Resolve is an OpenFX (OFX) plugin that adds film damage to a grade inside DaVinci Resolve. It composites the marks real film picks up — dust, fibers (a hair in the gate), scratches, stains, and gate-edge wear — onto a clip or Color node. It does not touch color.

Under the surface it is a native OFX Filter plugin whose damage is drawn in a single Metal pass. There is no scanned-asset library; everything is generated procedurally. Licensing is a local ed25519 signature check with zero network code, and the distributable is a signed, notarized, stapled `.pkg`. The OFX identifier is `com.chibatakumi.filmtone.resolve`. This note covers the three ideas that shaped it: deterministic damage, render-scale-decoupled placement, and offline licensing.

## A Procedural Film-Damage Pass

Five damage families render, each with an independent amount. With every amount at zero the output is a bit-exact identity — a true no-op — and damage is composited only where an amount is raised.

- **Dust**: irregular, mostly small specks with a skewed size distribution (a small-mote majority, a rare larger chip), clustered into bursts along the roll rather than sprinkled at a fixed cadence.
- **Fibers / hairs**: edge-anchored curved strands intruding partway into the frame, thickest at the root, tapering to a trembling tip — not free-floating vertical lines.
- **Scratches**: two populations sharing the contract ranges — long-lived tramlines and short cinch marks — with break-up, gaps, taper, and a core-plus-scuff cross-profile. Dark-led; the rare light scratch leans pale green-cyan rather than pure white.
- **Stains**: drying marks with density weighted toward an irregular rim and a faint interior veil, leaning slightly warm — a tide line, not a filled disc.
- **Gate-edge wear**: rail wear along the left and right frame edges, asymmetric side to side — edge streaking, deliberately distinct from an evenly darkened border.

Dark marks lead the polarity; bright sparkle stays rare and subordinate, so the composite never reads as an additive overlay on black.

## Deterministic Damage, Not Per-Frame Noise

Two common failure modes for film-damage effects are (1) re-rolling positions every frame, which flickers, and (2) stamping a scanned library, which tiles and repeats at high resolution.

Every artifact here is a pure function of a canonical cell / lane / slot plus hashes of the cycle, a per-event stream, and the frame index / host time. The same time, fps, and parameters produce the same artifacts on every render — no stored frames, no fresh dice roll per frame.

Deterministic is not the same as static. Each event has a lifetime and fade, with a held-visibility floor so presence reads as "arrive, hold, leave" rather than a slow ghost; liveliness comes from stepped micro-instability (a tick jump every few frames) instead of per-frame white noise. Scratches shimmer, dust clusters swell and fade, hair tips flutter — driven by time, reproducibly. Because each mark draws from its own event stream, there are no repeated stamps and no visible tiling at UHD.

## Proxy and Export Agree — Canonical Coordinates vs Render Scale

Colorists grade on a proxy and deliver at full resolution. If artifact placement depends on pixel resolution, the two disagree, and an approved proxy is not what ships.

The OFX coordinate model keeps spatial logic in canonical coordinates and converts to pixels only at buffer I/O. So all event geometry — the cell grid, radii, noise lattices, lanes, slots, and pattern phases — stays canonical, and the pixel-derived `antialiasWidth` never enters placement. It only widens smoothstep transitions and sub-pixel visibility floors. Proxy and full resolution therefore resolve the same event grid, and the marks land in the same place in both.

## Offline License Verification with Zero Network Code

The design rule is that the plugin contains no network code — no activation server, no online check. It runs in an offline post environment as-is, a server outage can never stall a render because there is nothing to reach, and there is nothing to explain about the plugin's data handling because it transmits nothing.

- **Format**: an envelope whose signed bytes are the payload itself. Public keys are embedded in the plugin, and the signed `kind` selects the verifying key internally. Strict canonical decoding rejects non-canonical, reordered, unknown-field, and tampered payloads as invalid.
- **Location**: `~/Library/Application Support/Filmtone/Filmtone.license` — the same filename and path for both purchased and trial licenses.
- **When it runs**: at instance creation and on a change to the license file's mtime only. There is no per-render I/O.
- **Expiry**: purchased licenses carry an explicit null `expiresAt` (perpetual); trials are issued at +14 days, compared against the render request time.
- **Enforcement**: unlicensed, expired, or invalid state runs full functionality and composites a watermark in the final pass (order: Dust → … → Watermark). When licensed with every family amount at zero, bit-exact identity is preserved.

The TypeScript signer uses WebCrypto; the C side vendors an ed25519 verify path (zlib-licensed). A fixture built from TS-signed envelopes plus adversarial vectors is checked for identical verdicts on the C side. The point is to close the crown-jewel failure — a valid full license misjudged as invalid, watermarking a paying customer — via fixture parity rather than hope.

## Distribution and Compatibility

Manual zip copies fail to install and turn straight into support and refund cost, so distribution is a `.pkg`: the bundle is signed with Developer ID Application, the installer with Developer ID Installer, then notarized and stapled. It lands at `/Library/OFX/Plugins/Filmtone.ofx.bundle` and loads when Resolve starts.

Compatibility is narrow and measured: verified on macOS 26.5.1 with DaVinci Resolve Studio 21.0.2. Other versions are not yet verified, and this is not a lower-bound guarantee. The internal evaluation version is 0.1.0 / build 1.

The effect is material-dependent: not every shot wants damage, and the right amount tracks the brightness and subject of the cut, so it is built to be eased up from low.

Filmtone for DaVinci Resolve — purchase and trial links go here at launch: 〔product page / Polar checkout — TBD〕

---

Editor notes (remove before publishing):

- No iOS / Desktop truth script applies here. Publish gate = owner approval in
  monetization progress.md (price, launch date, compatibility scope) plus
  confirmed product-page / Polar / pkg links.
- Launch date undecided; replace `〔... TBD〕` and the 30-day-window anchor once set.
- Compatibility is the measured pair only. Never write `macOS 14.0+` or
  `Resolve 21.x` as a floor.
- Do not describe the frozen generated recipe / adapter / contract internals;
  they are not load-bearing and misstating them breaks verify-before-documenting.
- Watermark string follows the install guide but is a placeholder pending the
  owner's visual sign-off; do not headline it.
