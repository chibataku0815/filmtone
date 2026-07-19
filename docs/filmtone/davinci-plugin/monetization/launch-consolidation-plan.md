# Filmtone DaVinci Plugin — Launch Consolidation Plan (計画書)

Date: 2026-07-19 JST
計画正本参照: [implementation-plan.md](implementation-plan.md) §6 (MON-5) / §7 (MON-6)
進行: [progress.md](progress.md)

Covers the two remaining owner-selected tracks after MON-2 core acceptance:
**(A) consolidate the combined plugin onto `main`** and **(B) MON-5 packaging**.
Legend: **C** = done autonomously / **C→O** = prepared, owner runs / **O** = owner only.

## Branch state (2026-07-19)

- `claude/davinci-ofx-integration` (`0b5669a`): the **final combined plugin** —
  spatial optics + Film Breath/Gate Weave/Film Damage + MON-2 license/watermark,
  identity unified to `com.chibatakumi.filmtone.resolve`, MON-5 build scaffolding
  (ProductVersion.mk, sign-bundle target, `Scripts/package.sh`). Builds arm64,
  **rebased onto current `main` and fast-forwardable**.
- `claude/davinci-plugin-pricing-plan-4cb87b`: monetization docs + the MON-2
  cross-verification harness (`scripts/license/parity/`) + records. Its *plugin*
  code is the older film-only lane, superseded by the integration branch.
- `main` (`9f8267a`, local; `origin/main` is behind): does not yet carry the OFX
  plugin. Lives in the **dirty primary worktree** (owner uncommitted iOS/AGENTS
  changes), so the trunk update is an owner action.

## Track A — consolidate onto main

| # | Step | Who | Note |
|---|---|---|---|
| A1 | Unify plugin identity to `.resolve` | **C** | Done (`0b5669a`). Spatial group ids stay `.finish.group.*` (cosmetic; needs a spatial-contract regen in visual-effect-core to fully clear — optional). |
| A2 | Fast-forward `main` → `claude/davinci-ofx-integration` | **C** | **Done 2026-07-19**: primary worktree was clean, `main` fast-forwarded to `0b5669a` (combined plugin now on local `main`). `origin/main` push is a separate, larger decision (publishes the whole unpushed davinci+spatial+iOS lane) — owner's call. |
| A3 | Bring monetization docs + MON-2 harness (`scripts/license/parity/`, `docs/.../monetization/`, `workstreams/license*`) onto `main` | **C→O** | These sit on the pricing-plan branch; port/merge them so `main` has the plan + verification tooling. Can be prepared on request. |

## Track B — MON-5 packaging (implementation-plan §6)

| # | Step | Who | Note |
|---|---|---|---|
| B1 | Version SoT + deployment target + sign target + `package.sh` | **C** | Done (`0b5669a`). `ProductVersion.mk` = 0.1.0 / build 1 / macOS 14.0. |
| B2 | Owner confirms marketing/build version before public build | **O** | Edit `ProductVersion.mk` first; Info.plist + pkg + filename follow. |
| B3 | Sign bundle + build signed .pkg + notarize + staple | **O** | `sh apps/filmtone-resolve-ofx/Scripts/package.sh`. **Prereqs missing on this machine (2026-07-19 check)**: only a Developer ID *Application* cert exists — no Developer ID *Installer* cert (create it in your Apple Developer account) and no stored notary credential (`xcrun notarytool store-credentials <profile> --apple-id ... --team-id C3G77H8NM6 --password <app-specific-pw>`). Once both exist, the script runs end-to-end. |
| B4 | Clean-Mac install → Resolve recognizes → trial→license→clean smoke | **O** | Verify on macOS 14.0+ / Resolve 21.x; publish only the measured range. |
| B5 | Upload .pkg to the Polar file-delivery benefit | **O** | No self-hosted delivery. |

## MON-2 residual (carried)

- GPU determinism (watermark-band race): owner elected to skip the md5 double
  export; documented narrow risk, `source->output` tracked-intermediate remedy
  ready. Core enforcement is live-verified (progress 改訂 22).
- Watermark visual: placeholder pending owner wording/opacity/size preferences.

## Next after this

MON-6 (implementation-plan §7): portfolio product page + release article (JP/EN)
+ launch pricing publish — all behind the release-truth + owner-approval gates.
