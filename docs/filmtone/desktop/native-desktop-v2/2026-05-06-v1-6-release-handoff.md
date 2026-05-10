# 2026-05-06 Native Desktop v1.6 Release Handoff

This handoff exists because the current chat lost the user's trust on Native
Desktop release scoping. The user said `あなたは何もわかっていません` and asked
for a complete handoff to a fresh chat. Treat this document plus the truth
scripts as the entry point. Do not assume any of the in-flight chat reasoning
was correct.

## 1. Why this handoff exists

- The user said `ではネイティブデスクトップ版のリリースをして下さい` after the
  current chat committed M8 desktop fixes as `1838f679`.
- The current chat asked an A/B/C/D scope question. The user picked **B**:
  *v1.6 として M8 fix を含む追加リリース*.
- The current chat then asked further clarifying questions about
  `PreviewSurface.swift` and ASC env. The user rejected this and asked for a
  full handoff document.
- Root reading the current chat got wrong: it treated the staged
  `PreviewSurface.swift` change as a *rejected* WIP. That was incorrect — see
  §6 below.

The next chat should follow this document, **read all referenced docs first**,
then re-confirm scope with the user before any release-scope action.

## 2. Repository

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

| Path | Role |
|---|---|
| `apps/filmtone-desktop-macos/` | Native Desktop v2 source |
| `apps/capacitor-film-lab-ios/` | iOS source |
| `docs/filmtone/desktop/native-desktop-v2/` | Native v2 2-layer docs (`strategy.md` + `active.md`) |
| `docs/filmtone/desktop/release-cutover/` | Release cutover docs (kept across releases) |
| `scripts/release-cutover-preflight.mjs` | Read-only preflight check |
| `apps/filmtone-desktop-macos/scripts/release-macos.sh` | Sign / notarize / staple `Filmtone.app` |
| `apps/filmtone-desktop-macos/scripts/package-dmg.sh` | Package / sign / notarize / staple DMG |
| `apps/filmtone-desktop-macos/scripts/upload-dmg-to-vercel-blob.mjs` | Public DMG upload (Vercel Blob + env sync) |
| `apps/filmtone-desktop-macos/scripts/upload-update-meta-to-vercel-blob.mjs` | Public update metadata switch |
| `apps/filmtone-desktop-macos/scripts/load-release-env.sh` | Sources `.env` files for ASC keys |

Branch / head at handoff:

- Branch: `main`
- Head: `1838f679 fix(desktop): M8 right-rail bottom extension and dead zone fix`
- Local main is **ahead of `origin/main` by 1 commit** (commit not pushed).
- Latest desktop tag: `desktop-v1.4`. **`desktop-v1.5` does NOT exist** even
  though v1.5 is publicly live (see §3).

## 3. v1.5 public release: ALREADY DONE earlier today

Confirmed live on 2026-05-06 JST. Do not repeat the v1.5 release. The next
version up is **v1.6**.

```bash
curl -fsS https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json
# {"schemaVersion":1,"latestVersion":"1.5","downloadPageUrl":"https://www.chibatakumi.studio/film-lab/download"}
```

| Public state | Value |
|---|---|
| `update-meta.json` `latestVersion` | `1.5` |
| Public DMG | `Filmtone-1.5.dmg` |
| DMG sha256 | `3d233125df33d8efe73f291f3122ade5babd28411cd4a9d3a6e3901a5a50257e` |
| Vercel deploys | `dpl_23pPBFELGLrqyvuTfvmBJDvpGEy4` (download), `dpl_9dUbRukQbfmrknVYPSC69MfG5yF4` (update env) |
| Download page | `https://www.chibatakumi.studio/film-lab/download` resolves to v1.5 DMG |

Archive:
`docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m7-native-desktop-v1-5-release.md`
— this is the **completed** v1.5 release record (all checklist items `[x]`).
It is currently in the `A` (added/staged) state but uncommitted.

## 4. Run the truth scripts FIRST

Do not trust this document or any prior chat handoff for release version
claims. Always rerun:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh \
  /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh \
  /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Snapshot at handoff time:

```text
Desktop:
  branch/head: main @ 1838f679
  native_marketing_version: 1.5
  native_build_version: 2
  public_latestVersion: 1.5
  latest_desktop_tag: desktop-v1.4
  commits_after_latest_tag: 40

iOS (separate lane, do not bundle into desktop release):
  public App Store version: 1.5 (or higher per refresh)
  local Xcode marketing version: 1.6
  local Xcode build: 5
```

`pbxproj`'s staged delta still reads `MARKETING_VERSION = 1.5` /
`CURRENT_PROJECT_VERSION = 2`. That is the **uncommitted artifact of the
already-shipped v1.5 release** — not the v1.6 target.

## 5. What the user wants from v1.6

User pick: **B — `v1.6 として M8 fix を含む追加リリース`**.

Authoritative scope per the user's pick (strictly — do not expand without
asking):

- Bundle the M8 fixes that landed as commit `1838f679` (M8 right-rail
  bottom extension + GlassEffectContainer dead zone fix).
- Bump Native Desktop `MARKETING_VERSION` to `1.6` and `CURRENT_PROJECT_VERSION`
  to a strictly higher number than the public v1.5 build (currently `2`).
  Apple expects monotonically increasing build numbers, so use `3` unless the
  user requests otherwise.
- Build / sign / notarize / staple `Filmtone.app`.
- Package / sign / notarize / staple `Filmtone-1.6.dmg`.
- Upload DMG to Vercel Blob and sync `FILM_LAB_DESKTOP_DOWNLOAD_URL`.
- Switch public update metadata `latestVersion` to `1.6`.
- Verify public truth.
- Tag `desktop-v1.6` (push by user; not by you).

## 6. CRITICAL: dirty worktree classification — do not misread it

The current chat misclassified the staged `PreviewSurface.swift` as a
*rejected* visual experiment. It is **not** that. The rejected version was
*Failed Attempt C* described in the M8 empty-CTA handoff (oversized button +
visible card-in-card plate). The current staged state is a **post-rejection
strip-down**: it removes the rejected card visually AND removes the empty-state
Open Button entirely. Read the staged diff before you decide.

| Path | Status | Real meaning | Default scope for v1.6 |
|---|---|---|---|
| `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` | `M ` (staged) | Uncommitted v1.5 release version bump (1.4→1.5 / 1→2). Already public. | **Edit further to v1.6 / 3 then commit as part of release** |
| `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift` | `M ` (staged) | **Strip-down**: removes empty-state Open button, replaces `Color.black` loaded backdrop with `MediaDerivedBackdrop` (blurred media), simplifies `BrandedOpeningBackdrop` (no `GlassEffectContainer`). Empty state becomes visual-only — users open via toolbar `Open` or `⌘O`. | **DECISION REQUIRED — see §7** |
| `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift` | ` M` (unstaged) | **Conditional mount** of Intensity row — only when an optical-filter chip is selected. Replaces the disabled-but-visible row that read as broken hardware. | **DECISION REQUIRED — see §7** |
| `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.5.md` | `A ` (staged) | Notes describing v1.5 features (already public). | **Either commit as v1.5 record AND author new `RELEASE_NOTES-v1.6.md`, or rename + rewrite** |
| `docs/filmtone/desktop/native-desktop-v2/active.md` | `A ` (staged) | M8 empty CTA active task (in progress, not the release lane). | **Pause per CLAUDE.md §4.5: move to `paused/` and replace with v1.6 release active.md** |
| `docs/filmtone/desktop/native-desktop-v2/2026-05-06-m8-empty-cta-click-handoff.md` | `A ` (staged) | Comprehensive handoff for the M8 empty CTA bug (separate lane). | **Keep as-is — DO NOT include in release commit; commit separately when M8 active resumes** |
| `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m7-native-desktop-v1-5-release.md` | `A ` (staged) | v1.5 release archive doc (release done). | **Commit as part of v1.5 archival commit OR fold into v1.6 release commit** |
| `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-empty-open-button-hit-testing.md` | `A ` (staged) | M8 archive (separate from CTA click bug). | **Commit separately or fold in** |
| `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-inspector-bottom-hit-testing.md` | `A ` (staged) | M8 archive (predecessor to dead zone fix). | **Commit separately or fold in** |
| `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m8-opening-open-panel-foreground.md` | `A ` (staged) | M8 archive (Open panel route fix). | **Commit separately or fold in** |
| `docs/filmtone/desktop/release-cutover/2026-05-05-native-v2-replacement-readiness.md` | `M ` (staged) | Updated to record v1.5 cutover. | **Update again for v1.6 then include in release commit** |
| `docs/filmtone/desktop/release-cutover/README.md` | `M ` (staged) | Cutover doc index update. | **Update for v1.6 if needed** |
| `scripts/release-cutover-preflight.mjs` | `M ` (staged) | De-hardcoded from v1.4 → reads release notes from project version. | **Probably already v1.6-compatible; rerun and verify** |
| `apps/capacitor-film-lab-ios/**` | mixed | iOS lane (fastlane / metadata / pbxproj / Swift / scripts). Separate release. | **EXCLUDE — iOS user owns separately** |
| `docs/filmtone/ios/2026-05-06-filmtone-ios-meta-before-after-davinci-handoff.md` | `M ` (staged) | iOS doc edit. | **EXCLUDE** |
| `.codex_create_lut_wipe_l2r.lua` | `??` | Untracked codex script. | **Ask user; default leave untouched** |

Always re-confirm by running `git status --short --branch` and inspecting any
diff with `git diff --staged <path>` / `git diff <path>` before reasoning.

## 7. Open decision points (must resolve with user before destructive ops)

1. **`PreviewSurface.swift` staged scope**
   - **A.** Ship the strip-down in v1.6. Means v1.6 has *no* empty-state Open
     button; user opens via toolbar `Open` or `⌘O`. Pro: avoids the click-area
     bug entirely. Con: regressed empty-state CTA affordance.
   - **B.** Revert the staged change. Ship v1.6 with the v1.5-shipped empty-state
     Open button (which has the click-area bug per the M8 empty-CTA handoff).
     Pro: keeps CTA affordance. Con: known click bug ships unfixed.
   - **C.** Hold v1.6, finish M8 empty-CTA active first, then release. Pro:
     ships proper fix. Con: same-day churn deferred; M8 active work blocked
     trust per the handoff.

2. **`QuickAdjustControls.swift` unstaged scope**
   - **A.** Stage and ship the conditional Intensity row mount in v1.6.
     Pro: cosmetic improvement, small risk.
   - **B.** Revert. Ship v1.6 with v1.5 behavior (always-mounted, disabled-when-None).

3. **Build number choice**
   - Default: `CURRENT_PROJECT_VERSION = 3` (v1.5 was build `2`). Confirm.

4. **ASC env source**
   - Only `apps/capacitor-film-lab-ios/.env.local` exists. No
     `apps/filmtone-desktop-macos/.env(.local)` and no
     `apps/filmtone-desktop-macos/fastlane/.env(.local)`.
   - Confirm with user: does `apps/capacitor-film-lab-ios/.env.local` carry
     `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_PATH` for shared use? If not,
     user must `export` them in the shell before sign/notarize.

5. **Bundling other staged docs into the release commit**
   - The `A` archive docs (m7 release, m8 hit-testing trio) and the `M`
     cutover docs and the `M` preflight script are all release-adjacent. Default
     to a single release commit. Confirm scope.

6. **Push policy**
   - Per project `CLAUDE.md` §9: `Git 操作は user が行う`. Default: do **not**
     push, do **not** tag without explicit user permission. The user has
     authorized release execution for this lane but tag/push must be confirmed
     at the moment.

## 8. The 2-layer rule (Native Desktop v2)

Per `CLAUDE.md` §4.5 and `strategy.md`'s Operating Rules:

- Read `strategy.md` then `active.md` at session start.
- Keep only one `active.md` at a time.
- For a release lane that interrupts the current `active.md` (M8 empty CTA):
  1. Append `Paused` to current `active.md` and move it to `paused/`.
  2. Create a new `active.md` for the v1.6 release lane.
  3. On completion, archive the v1.6 release `active.md` and add 1–3 lines to
     `strategy.md` Completion Log; restore the M8 empty CTA `active.md` from
     `paused/`.
- Milestone-changing interrupts: add a short note to `strategy.md`
  `Interrupt / Decision Log` before creating the new `active.md`.

## 9. Release process reference (per `archive/2026-05-06-m7-native-desktop-v1-5-release.md`)

Pre-release verification:

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:macos
bun run release:cutover-preflight
git diff --check
```

Build / sign / notarize / staple:

```bash
# Required env (confirm available before running):
#   ASC_KEY_ID=TM2BK9269B
#   ASC_ISSUER_ID=<App Store Connect issuer UUID>
#   ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_TM2BK9269B.p8

apps/filmtone-desktop-macos/scripts/release-macos.sh
apps/filmtone-desktop-macos/scripts/package-dmg.sh

# Re-run preflight after DMG exists:
bun run release:cutover-preflight
```

Manual visual checkpoint (do not skip):

```bash
open apps/filmtone-desktop-macos/build/release/1.6/Filmtone-1.6.dmg
```

Verify in the mounted DMG:

- `Filmtone.app` installs over the previously-installed Native Desktop.
- `spctl` / Gatekeeper accepts the app and DMG (Notarized Developer ID).
- Launched app reports Bundle ID `com.chibatakumi.film-lab-desktop`.
- App opens stills and videos and exports.

Public upload (high blast radius — confirm with user before each):

```bash
# 1. DMG first; updates the fixed download URL but does not yet trigger update prompts.
bun run release:upload-dmg -- --confirm-prod --sync-vercel-env

# 2. Update meta last; this triggers v1.5 clients to show the upgrade prompt.
bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env
```

Post-release truth verify:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh \
  /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

curl -fsS https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json
```

Expected post-release:

- `public_latestVersion: 1.6`.
- Public download page contains `Filmtone-1.6.dmg`.
- Public DMG HEAD returns `200` with `filename="Filmtone-1.6.dmg"`.

Tag (commit + tag scope confirmed with user):

```bash
git tag desktop-v1.6
# Push owned by user.
```

## 10. Rollback

If failure happens before `update-meta.json` is switched, no v1.5 user is
affected. Restore `FILM_LAB_DESKTOP_DOWNLOAD_URL` to the v1.5 DMG URL if it was
already changed.

If failure happens after `update-meta.json` is switched, immediately upload
rollback metadata with `latestVersion: "1.5"` and the v1.5 DMG download page,
then redeploy portfolio if env values changed.

The v1.5 rollback target is currently:

- `latestVersion: "1.5"`
- `downloadPageUrl: "https://www.chibatakumi.studio/film-lab/download"`
- Public DMG already at v1.5 (sha256 above).

## 11. v1.5 → v1.6 release notes scope (proposed)

```markdown
# Filmtone Desktop v1.6

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only (macOS 26+)
- Architecture: Universal (arm64 + x86_64)
- Official artifact: signed + notarized DMG

## What changed

> v1.6 is a focused bug-fix release on top of v1.5 to restore full
> right-rail control reachability when a video source is loaded.

### Right rail reaches the window bottom

The right inspector rail now extends to a 24pt window-bottom inset on every
source kind. The floating scrub bar reserves a right gutter equal to the rail
footprint when the inspector is open, shrinking the scrub capsule horizontally
so it lives alongside the rail instead of disappearing behind it.

### Right rail lower-half hit dead zone fixed

Removed the macOS 26 `GlassEffectContainer` wrapper around the inspector
ScrollView. Its NSView-backed morphing surface was claiming hits in the lower
window y-band, and SwiftUI `.zIndex(2)` could not reorder past it. Per-panel
`.glassEffect` is innocent and remains in place — panels render as discrete
Liquid Glass capsules instead of morphing into adjacent ones, but the entire
rail accepts hover, click, drag, and scroll from top to bottom.

[OPTIONAL — only if §7.1 chooses A:]
### Empty state simplified
The empty state now shows the brand mark, title, and instruction text only.
Open material from the toolbar `Open` button or `⌘O`.

[OPTIONAL — only if §7.2 chooses A:]
### Quick adjust intensity row
The Backlight Veil intensity slider now mounts only when a density chip is
selected, so an inactive panel no longer shows a disabled-looking slider.

## Compatibility

- Requires macOS 26 or later.
- Sidecar output is unchanged; v1.6 does not require a schema bump.
- Existing Native Desktop users should replace the app from the v1.6 DMG.

## Checksum

```text
<sha256 from package-dmg.sh output>  Filmtone-1.6.dmg
```

## Feedback

- GitHub Issues: `https://github.com/chibataku0815/filmtone/issues`
```

Adjust based on §7 decisions.

## 12. Constraints (CLAUDE.md / AGENTS.md / memory — must honor)

From `CLAUDE.md`:

- **bun mandatory**. No npm / yarn / pnpm.
- **本質優先 / 外殻最小**. Do not pad release with optional QA scaffolding the
  user did not request.
- **Sequential-thinking** for design judgments; do not assert from memory.
- **Verify before quoting handoffs** — `feedback_verify_before_quoting_handoff`.
- **No silent stream redefine** — `feedback_no_silent_stream_redefine`.
- **`git push` / tag is user-driven** unless explicitly authorized.
- **Native Desktop v2 2-layer docs are canonical** — `strategy.md` then
  `active.md`. Do not implement without an `active.md`.
- **Vocabulary lock**: `動画` / `video` (not `短尺動画`); `Preset` ≠ `Look`.
- **Anti-patterns**: do not republish via npm; do not delete tracked
  `packages/*/dist/`; do not place JSX comments at root return location.

From `AGENTS.md` (read at session start; 239 lines):

- Long-running task model (`strategy.md` + `active.md` 2-layer).
- Verification commands.
- Auto-commit禁止.

From auto-memory (highlights — full index in the session):

- `feedback_no_landed_claim_before_commit` — claim landed only after
  `git log` confirms commit.
- `feedback_no_black_matte_for_glass_exposure` — do not paint black matte over
  Liquid Glass; use a media-derived blurred backdrop. (The current
  `PreviewSurface.swift` staged change implements exactly this for the loaded
  state — recognize this pattern.)
- `feedback_nsviewrepresentable_blocks_liquid_glass` — Liquid Glass cannot
  sample through `NSViewRepresentable`-backed views; relevant if any release
  visual change wants Glass over an NSView.
- `feedback_apple_liquid_glass_canonical_name` — write `Apple Liquid Glass`
  (do not abbreviate to `Liquid Glass` alone) in any user-facing copy.
- `feedback_check_legacy_ui_conventions_before_new_ui` — grep iOS / desktop
  conventions before adding shortcuts or labels.
- `project_native_v2_replaces_electron` — Electron 1.0.3 = frozen legacy.

## 13. What the current chat (about to end) actually did

For full continuity, the current chat:

1. Read `EditorSidebar.swift` and confirmed `GlassEffectContainer` is removed.
2. Reviewed the existing M8 plan file
   `/Users/chibatakumi/.claude/plans/you-are-continuing-a-playful-codd.md`
   (root-cause = AVPlayerView default `hitTest`, with diagnostic-first
   approach via `Color.black` substitution). Per the strategy.md log entry
   2026-05-06 the dead-zone root cause was actually `GlassEffectContainer`,
   not AVPlayerView; the AVPlayerView hypothesis in that plan file is
   superseded.
3. Ran the release truth script and curl on the public update-meta. Confirmed
   v1.5 is publicly live.
4. Read all the M8 archive docs and the M8 empty-CTA handoff.
5. Asked the user A/B/C/D scope question. User picked B.
6. Asked further clarifying questions about the staged
   `PreviewSurface.swift` and ASC env. User responded
   `あなたは何もわかっていません` and asked for this handoff.

Errors made by the current chat (next chat must avoid):

- Treated staged `PreviewSurface.swift` as a *rejected* WIP. It is the
  *post-rejection strip-down* — see §6.
- Asked clarifying questions before reading `2026-05-06-m8-empty-cta-click-handoff.md`
  thoroughly enough to map the staged diff to the right mental model.
- Did not check `AGENTS.md` until the user pushed back.

## 14. Recommended next-chat sequence

Read in this order before any action:

1. `AGENTS.md` (239 lines)
2. `CLAUDE.md` (project)
3. `docs/filmtone/desktop/native-desktop-v2/strategy.md`
4. `docs/filmtone/desktop/native-desktop-v2/active.md` (currently M8 empty CTA)
5. `docs/filmtone/desktop/native-desktop-v2/2026-05-06-m8-empty-cta-click-handoff.md`
6. `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m7-native-desktop-v1-5-release.md`
7. `docs/filmtone/desktop/release-cutover/2026-05-05-native-v2-replacement-readiness.md`
8. This handoff doc.

Then:

1. Run both truth scripts (§4) to confirm state has not drifted since this
   handoff.
2. Inspect dirty diffs:
   - `git status --short --branch`
   - `git diff --staged apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
   - `git diff apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
   - `git diff --staged apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
3. Re-confirm scope with user using §7 decision points. Present each as a
   concrete pair of options, not open-ended.
4. Pause M8 empty CTA `active.md` per §8.
5. Create new `active.md` for v1.6 release using m7 archive as template.
6. Bump `pbxproj` to v1.6 / build 3.
7. Author `RELEASE_NOTES-v1.6.md` per §11.
8. Verify: `Verify/run.sh`, `verify:macos`, `release:cutover-preflight`, `git diff --check`.
9. Sign / notarize / staple app and DMG.
10. Stop. Have user inspect the DMG mount.
11. Upload DMG (`--confirm-prod --sync-vercel-env`).
12. Stop. Verify download URL points to v1.6.
13. Upload update-meta (`--confirm-prod --sync-vercel-env`).
14. Verify public truth.
15. Commit release artifacts to main and tag `desktop-v1.6` only after user
    explicitly confirms scope. Push is user-owned.

## 15. Stop conditions

Stop and report instead of looping if any of these happen:

- ASC env not present and user cannot provide it.
- `bun run verify:macos` or `Verify/run.sh` fails 3 times.
- `release-cutover-preflight` reports a mismatch the next chat cannot resolve
  read-only.
- Notarization fails.
- DMG manual inspection finds Gatekeeper rejection or Bundle ID mismatch.
- Vercel upload returns non-2xx.
- User rejects any §7 decision point or asks for re-scoping.

## 16. Out of scope for v1.6

- iOS lane (separate release; iOS dirty files are user-owned).
- Mac App Store submission (secondary exit per m7 archive — not blocking).
- Portfolio submodule bump (separate user-owned step after release).
- M8 empty CTA fix (paused; resume after release).
- Any feature work beyond §7 decisions.

---

## English Handoff Prompt (paste into the new chat verbatim)

```text
You are continuing a Filmtone Native Desktop v2 release task in:

  /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

The previous chat lost the user's trust on release scoping. The user said
"あなたは何もわかっていません" (you understand nothing) and asked for a
clean handoff. Treat the prior chat's reasoning as suspect; verify
everything from source.

GOAL
====

Ship Native Desktop v1.6, a focused bug-fix release on top of the already-
public v1.5. v1.6 must include the M8 fixes from commit 1838f679 (right
rail bottom extension + GlassEffectContainer dead zone fix). Public exit
is the signed, notarized, stapled Developer ID DMG uploaded to the fixed
Desktop download rail with update metadata reporting "1.6".

The user already chose this scope ("B"). Do not re-litigate it. Do
re-confirm the open decision points in section 7 of the handoff doc
before destructive ops.

REQUIRED READING (before any action, in order)
==============================================

1. AGENTS.md (repo root, 239 lines).
2. CLAUDE.md (repo root, project rules).
3. docs/filmtone/desktop/native-desktop-v2/strategy.md
4. docs/filmtone/desktop/native-desktop-v2/active.md
5. docs/filmtone/desktop/native-desktop-v2/2026-05-06-m8-empty-cta-click-handoff.md
6. docs/filmtone/desktop/native-desktop-v2/archive/2026-05-06-m7-native-desktop-v1-5-release.md
7. docs/filmtone/desktop/release-cutover/2026-05-05-native-v2-replacement-readiness.md
8. docs/filmtone/desktop/native-desktop-v2/2026-05-06-v1-6-release-handoff.md  ← THIS HANDOFF

Then run both truth scripts and inspect the staged diffs in section 6 of
the handoff doc:

  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh \
    /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

  /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh \
    /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

  git status --short --branch
  git diff --staged apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift
  git diff apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift
  git diff --staged apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj

CRITICAL FACTS TO INTERNALIZE BEFORE PROPOSING ANY ACTION
=========================================================

- Native Desktop v1.5 is ALREADY PUBLIC (released earlier today,
  2026-05-06 JST). Do not re-release v1.5. Verify with the truth script.

- Local main is one commit ahead of origin/main (1838f679 not pushed).
  The repo is on the main branch (no separate worktree).

- Latest desktop git tag is desktop-v1.4. desktop-v1.5 was never tagged
  even though v1.5 is publicly live. Do not infer release state from tags.

- The staged apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift
  diff is NOT the rejected oversized-button WIP. It is a post-rejection
  STRIP-DOWN that:
    * removes the empty-state Open button entirely
    * replaces the loaded-state Color.black backdrop with a
      MediaDerivedBackdrop (blurred media)
    * simplifies BrandedOpeningBackdrop (no GlassEffectContainer)
  Shipping it in v1.6 means the empty state has no Open button — users
  open via the toolbar Open action or ⌘O. This is decision §7.1; ask
  the user before assuming.

- The unstaged QuickAdjustControls.swift diff conditionally mounts the
  Intensity row only when an optical-filter chip is selected. Cosmetic
  improvement. This is decision §7.2; ask the user before assuming.

- The staged pbxproj is currently MARKETING_VERSION 1.5 / build 2 — that
  is the v1.5 release artifact (uncommitted). For v1.6 you must edit it
  to MARKETING_VERSION 1.6 / build 3 (or higher; confirm with user).

- iOS dirty worktree files (apps/capacitor-film-lab-ios/**, docs/filmtone/ios/**)
  are NOT part of the desktop release. Exclude them from any release
  commit.

- Per CLAUDE.md, git push and tag are user-driven. The user has
  authorized release execution but not preemptive push. Always pause for
  explicit confirmation at the points marked in section 14 of the
  handoff doc.

- Per CLAUDE.md §4.5 the Native Desktop v2 2-layer model (strategy.md +
  active.md) is canonical. The current active.md is M8 empty CTA. Pause
  it (move to paused/, append "Paused" note) before opening the release
  active.md.

CONSTRAINTS
===========

- bun, not npm.
- macOS 26 only.
- 用語ロック: 動画/video (never 短尺動画), Preset ≠ Look.
- Liquid Glass canonical name: write "Apple Liquid Glass", never bare
  "Liquid Glass", in user-facing copy.
- No black-matte over Apple Liquid Glass (use media-derived blurred
  backdrop — the staged PreviewSurface change does this for the loaded
  state).
- Do not delete packages/film-lab-renderer/dist or
  packages/film-lab-smart-look/dist; they are intentionally tracked.
- Do not declare a release "landed" until git log confirms the commit
  and the public truth script confirms latestVersion 1.6.
- Do not repeat the previous chat's mistake of asking clarifying
  questions before reading the M8 empty CTA handoff and AGENTS.md.

OPEN DECISIONS TO RESOLVE WITH THE USER (cite §7 of handoff doc)
================================================================

D1. Ship staged PreviewSurface.swift strip-down (no empty CTA), revert
    it (keep v1.5 CTA + click bug), or hold v1.6 until M8 empty CTA
    fixed?
D2. Stage and ship QuickAdjustControls.swift conditional Intensity row
    mount? Or revert?
D3. Build number: default 3. Confirm.
D4. ASC env: only apps/capacitor-film-lab-ios/.env.local exists; does it
    carry shared ASC keys, or will the user export ASC_KEY_ID,
    ASC_ISSUER_ID, ASC_KEY_PATH manually?
D5. Bundle the staged release-adjacent docs (m7 archive, m8 hit-testing
    archives, cutover docs, preflight script) into the release commit?
D6. Tag desktop-v1.6 immediately after the meta switch verifies, or
    wait?

Present D1–D6 as concrete option pairs. Do not open-end them.

EXECUTION SEQUENCE (after D1–D6 are resolved)
=============================================

1. Pause M8 empty CTA active.md (move to paused/, append "Paused").
2. Create new active.md for v1.6 release (use m7 archive as template).
3. Edit pbxproj: MARKETING_VERSION 1.6, CURRENT_PROJECT_VERSION 3.
4. Apply D1 / D2 decisions to PreviewSurface.swift / QuickAdjustControls.swift.
5. Author RELEASE_NOTES-v1.6.md (template in §11 of handoff doc).
6. Update release-cutover docs and preflight script for v1.6 if needed.
7. Verify:
     bash apps/filmtone-desktop-macos/Verify/run.sh
     bun run verify:macos
     bun run release:cutover-preflight
     git diff --check
8. Sign / notarize / staple:
     apps/filmtone-desktop-macos/scripts/release-macos.sh
     apps/filmtone-desktop-macos/scripts/package-dmg.sh
     bun run release:cutover-preflight   # rerun after DMG exists
9. STOP. Have the user open and inspect the v1.6 DMG mount.
10. Upload DMG:
     bun run release:upload-dmg -- --confirm-prod --sync-vercel-env
11. STOP. Verify download URL resolves to Filmtone-1.6.dmg.
12. Upload update-meta:
     bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env
13. Verify public truth:
     /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh \
       /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
     curl -fsS https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json
14. Path-scoped commit of release artifacts to main; tag desktop-v1.6.
    (Push owned by user; do not push.)
15. Archive the v1.6 release active.md and append 1–3 lines to
    strategy.md Completion Log.
16. Restore the M8 empty CTA active.md from paused/.

STOP CONDITIONS
===============

Stop and report immediately if:
- ASC env unavailable.
- 3 consecutive build / verify / sign / notarize failures.
- Preflight reports a mismatch.
- DMG manual inspection finds Gatekeeper rejection or Bundle ID
  mismatch.
- Vercel upload returns non-2xx.
- User rejects any decision or asks for re-scoping.

ROLLBACK
========

If failure happens before update-meta switch: restore
FILM_LAB_DESKTOP_DOWNLOAD_URL to the v1.5 value if it was changed, no
v1.5 user is impacted.

If failure happens after update-meta switch: immediately upload
rollback metadata with latestVersion 1.5 and the v1.5 download page,
then redeploy portfolio if env values changed.

Output style: Japanese for user-facing summaries (per CLAUDE.md);
English for internal reasoning and tool prompts. Use file_path:line
references. Be terse and action-oriented. Do not auto-commit unless
explicitly asked.
```
