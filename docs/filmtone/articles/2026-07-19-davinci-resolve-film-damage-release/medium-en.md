# The Dust Stays Where You Put It — Film Damage for DaVinci Resolve

Status: candidate draft (pre-launch). Do not make any public state, price,
launch-date, or compatibility claim until owner approval is confirmed in the
monetization progress.md (the coordinator-owned truth). The iOS / Desktop
truth scripts do not apply to this product.

Publication switch:

- Before launch: keep `upcoming`, `at launch`, `will be`. Avoid `released`,
  `now available`, `we shipped`.
- After launch (owner-approved): change the title's framing to shipped, set the
  first line to `Filmtone for DaVinci Resolve is out.`, and replace price,
  launch date, and purchase links with confirmed values.

TOC policy: Medium has no native table of contents and does not expose anchor
IDs. Do not add a TOC. Keep H2 subheads short and self-contained.

---

You have locked the grade. For a period piece, or just a film feel, you want the print to look handled — a little dust, a hair caught in the gate, a scratch that comes and goes. So you reach for a damage overlay. And something about it never quite sits on the picture.

The dust jumps to a new place every frame. A scratch floats on a black shot like a sticker on glass. And the dust you carefully lined up on the proxy lands somewhere else once you export at full resolution. The damage is behaving like a moving pattern glued to the screen, not like something that happened to the film.

Filmtone for DaVinci Resolve is a small OpenFX plugin that adds film damage to a grade inside DaVinci Resolve. You drop it on a clip or a Color node, and it composites the marks real film picks up — dust, fibers, scratches, stains, gate-edge wear — on top of the color you already set. It does not change your color. It adds the wear.

Real print damage is not uniform, and it is not pure noise either. Dust is mostly small and dark, with the occasional larger chip. Scratches break up, taper, and go ragged at the edges. A hair enters from the frame edge and sits there, trembling slightly, for a while. Filmtone renders that physical bias — and, given the same settings and the same point in time, it renders the same damage on every pass. What you see on the proxy is where it lands in the export.

## What Lands on the Frame

Five families, each with its own amount. Set them all to zero and the output is identical to the input — nothing is added to that shot. Damage appears only where you turn something up.

- **Dust**: mostly small, irregular specks, with a rare larger chip — a skewed size distribution, not uniform dots. Because real dirt arrives unevenly along a roll, dust clusters into bursts rather than sprinkling at a fixed rate.
- **Fibers / hairs**: curved strands anchored at the frame edge, intruding partway in — the classic hair in the gate. Thick at the root, tapering to a tip that trembles. No free-floating vertical lines in the middle of the frame.
- **Scratches**: two populations sharing the same ranges — long-lived tramlines and short, fine cinch marks — with break-up, gaps, taper, and a scuffed edge. Mostly dark; the rare light scratch leans pale green-cyan rather than pure white, the way emulsion-side damage actually reads.
- **Stains**: drying marks with the deposit weighted toward an irregular rim and a faint veil inside, leaning slightly warm — a tide line, not a filled translucent blob.
- **Gate-edge wear**: rail wear along the left and right edges, asymmetric side to side. This is edge streaking, not a vignette that darkens the whole border evenly.

Dark marks lead; bright sparkle stays rare and subordinate, so the picture never reads as an additive overlay sitting on top of black.

The effect is material-dependent. Not every shot wants damage, and the right amount changes with the brightness and subject of the cut, so the plugin is built to be eased up from low rather than switched on.

## Proxy and Export Agree

The quiet, important property here is that the damage is repeatable.

Most damage tools either re-roll positions every frame — which flickers — or stamp a scanned library, which tiles and repeats. Worse, the marks you place on a proxy can resolve somewhere else at full resolution, so a grade checked on the proxy is not the grade you deliver.

Filmtone places every artifact in normalized coordinates, decoupled from render scale. Proxy and full resolution resolve the same events, so the dust and scratches land in the same place in both. Re-render the same point in time with the same settings and you get the same result.

That is not the same as static. Scratches shimmer, dust clusters swell and fade, a hair's tip flutters — the film-like liveliness is there, it is just driven by time rather than by a fresh dice roll each frame. Zoom to UHD and there is no visible tiling, because each mark is drawn from its own event stream instead of a repeated stamp.

The most expensive kind of redo — the picture changing between the version you approved and the version you shipped — is closed off by construction.

## Buy It Once, and Try It on a Real Delivery First

Filmtone for DaVinci Resolve is a one-time purchase. Not a subscription.

- Regular price: $49
- Launch price: $39 for the first 30 days after launch (a fixed $10-off coupon)
- 1 user / 2 machines
- Commercial use allowed, with no budget tier
- Free updates through v1.x

The nearest equivalent tool for this kind of film-damage work is sold subscription-only. Filmtone is a one-time purchase instead of a recurring one — which matters most for an effect you reach for a few times a year rather than every day.

You can try it two ways:

- **No signup, any time.** Without a license the plugin runs with full functionality; the output just carries a visible trial watermark. No account, no payment — you evaluate the effect on your own footage immediately.
- **14 days, watermark-free.** Request a trial license with your email address and you get 14 days of clean output. When the 14 days are up, it reverts to the watermarked state on its own.

Because this product's value is subtle temporal behavior, that clean window lets you take one real job all the way to delivery before deciding. Evaluating it on a real timeline, at real length, is the fastest way to know.

## No Network Code, by Design

**The plugin contains no network code at all.**

Licensing is an ed25519-signed file checked locally — no activation server, no online check. That is a choice, not a shortcut. It drops straight into an offline post environment, and a server outage can never stall a client's render, because there is nothing to reach. There is also nothing to explain about the plugin's data handling: it sends nothing.

One clarification, so the claim stays honest: the plugin not talking to the network is separate from requesting a trial. The only time an email address is involved is when you request the 14-day clean trial, so the license can be emailed to you. Nothing else about the plugin phones home.

## What to Try First

The distributable is a signed, notarized installer, `Filmtone-<version>.pkg`, so macOS opens it without a security warning. Install it (Resolve quit first), relaunch Resolve, and:

1. Add `Filmtone` from the Color page `Effects Library` (or `Add Tool` in Fusion) onto a clip or node.
2. Ease up Dust and one scratch family on a darker, quieter shot first — that is where wear reads most clearly.
3. For a real evaluation, request the 14-day clean trial and run one actual delivery through it.

Compatibility for this version is narrow and measured: verified on macOS 26.5.1 with DaVinci Resolve Studio 21.0.2. Other versions are not yet verified.

Filmtone for DaVinci Resolve — purchase and trial links go here at launch: 〔product page / Polar checkout — TBD〕

---

Editor notes (remove before publishing):

- This product has no iOS / Desktop truth script. The publish gate is owner
  approval in monetization progress.md (price, launch date, compatibility
  scope) plus confirmed product-page / Polar / pkg links.
- Launch date is undecided. Replace `〔... TBD〕` and "for the first 30 days
  after launch" anchors with the real date once set.
- Compatibility is the measured pair only (macOS 26.5.1 / Resolve Studio
  21.0.2). Never write `macOS 14.0+` or `Resolve 21.x` as a floor.
- Watermark wording follows the install guide (`FILMTONE — TRIAL`) but the
  exact string is a placeholder pending the owner's visual sign-off; do not
  build a headline on it.
