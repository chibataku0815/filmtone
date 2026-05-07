# Active: M9 — Native Recording Export Completion

Date: 2026-05-08 JST
Branch: TBD (cut a fresh worktree off post-M8 main when implementation
starts; do not start on the M6 worktree branch — that lane is closed)
Base: `main` after the M6 → main merge (`6bc3eda0`) + Lane A
(`0448c484`)

Status: **LANDED — S5 owner walk PASS on iPhone 17 Pro / iOS 26.4.2 (2026-05-08)**

Closeout: implementation = `138ac7ba` (worktree branch
`worktree-feature+ios-m9-recording-export-completion`). S5 acceptance
criterion ("録画した動画を、迷わず保存または共有できるか") confirmed by
owner. UI/UX polish observed during the walk is deferred — out of scope
for M9 (出口可視化 lane); a separate polish lane will pick that up.

## Why this active exists

M8 closed the *input* side of native recording: tap CTA → see countdown
→ land in the editor on the captured clip. The *output* side has never
been finished as a product surface — the user can apply a Preset, but
"applied look" → "Filmtone artifact in a place I can use it" has no
clear primary exit, no destination feedback, and no decided save / share
hierarchy.

This lane decides the primary exit and implements it. Not "investigate
→ observe → verify" — **decide → implement → one acceptance**.

## Product loop M9 must deliver

1. From a recording-derived source, tapping Export runs the existing
   export pipeline without a record-only branch.
2. Save (Photos) is the **primary** post-export CTA. Share is
   **secondary**. Both are visible on the export-complete surface; no
   destination ambiguity.
3. The export-complete surface tells the user what landed, where it
   landed, and (when applicable) the resulting filename — using
   existing toast / sheet / message surfaces, not new chrome.
4. Export, save, and share failures land on the existing alert /
   message path. No silent swallow, no stuck `isBusy`, no notice-less
   `.failed` state.
5. Recording-derived export result is treated identically to a Photo
   Library / Files source export in the editor / export panel.

## Out of scope for M9

- React/Capacitor stack purge.
- Directory rename `apps/capacitor-film-lab-ios/` → `apps/filmtone-ios/`.
- Capture-time honest preview (strategy M8's preview half).
- Preview / preset polish, look library surface changes.
- Multi-device acceptance matrix. iPhone 17 Pro / iOS 26.4.2 only.
- Recording-stop gesture, capture-surface contract changes.
- Doc cleanup, strategy rewrite, formal QA matrix.
- New export pipeline. Reuse `FilmtoneEditorStore.export()` /
  `exportAndSave()` / `saveToPhotos()` / `shareOutput()` and
  `FilmtoneExportPanel`.
- Pre-imagined failure-path device matrix. S5 acceptance is one
  product-flow walk, not a 4-path test grid.

## Subtask plan (≤30 min each, sequential)

S1 — **Read current export/save/share surface** (≈20 min, no code
   changes)

   Read-only sweep to confirm wiring before editing:
   - `FilmtoneEditorStore.export()` / `exportAndSave()` /
     `saveToPhotos()` / `shareOutput()` — confirm `shareOutput` exists
     and returns to the same notice/error path.
   - `FilmtoneExportPanel` — confirm what it shows on
     `exportResult != nil`, `saveToPhotosState`, and `isSavingToPhotos`.
     Note where the primary-vs-secondary CTA hierarchy lives today.
   - `FilmtoneExportSession.exportVideo` capture-package source
     handling and the resolved output URI / filename surface.
   - `FilmtoneRootView` `.alert($store.error)` binding to confirm
     export-side errors raise the existing alert (separate from
     `recordingError`).

   Output: a 5-line "current state" note inline in this active.md
   (under "Implementation notes") naming what's already correct and
   what specifically needs editing in S2-S4.

S2 — **Primary CTA hierarchy on the export-complete surface**
   (≈30 min)

   Make Save (Photos) the primary action and Share the secondary
   action on the post-export surface. If today both are equal-weight,
   demote share to secondary styling / lower position. If today only
   one is wired, wire the missing one — no new pipeline, just the
   existing `saveToPhotos()` / `shareOutput()` calls already on
   `FilmtoneEditorStore`.

S3 — **Destination feedback on the export-complete surface**
   (≈30 min)

   On `saveToPhotosState == .saved`, the user sees a localized
   "saved to Photos" notice (existing toast / message surface, not
   new chrome). On share-sheet completion (or cancel), the export
   panel returns to its idle export-complete state without a stuck
   `isSavingToPhotos`. Filename surfacing only if S1 shows the
   existing surface already exposes it; otherwise skip — out-of-scope
   redesign.

S4 — **Export / save / share failures route to the existing alert
   path** (≈30 min)

   Each of: `export()` thrown error, `saveToPhotos()` PHPhotoLibrary
   error, `shareOutput()` failure → flips `store.error` to the
   localized `userMessage(for:context:)` and clears `isBusy` /
   `isSavingToPhotos` so the user can retry. No silent fallback
   (`feedback_no_fallback_bug_hotbed`).

S5 — **Owner closing-loop acceptance** (≈15 min, no code)

   Owner walks record → edit → preset → export → save (or share) once
   on iPhone 17 Pro / iOS 26.4.2 after S2-S4 land. If primary save
   succeeds and the destination is unambiguous, the lane is done. A
   single failing observation reopens the relevant Sn — do not expand
   into a 4-path failure matrix.

## Implementation notes (S1 current-state, 2026-05-08)

S1 read confirms most of the surface already exists; the real M9 work
is narrower than S2-S4 originally implied:

1. **Save = primary / Share = secondary already wired**
   (`FilmtoneExportPanel:210-224` via `FilmtonePrimaryButtonStyle` vs
   `FilmtoneSecondaryButtonStyle`). S2 needs no Swift edit.
2. **Save-success destination feedback already complete** — amber chip
   (`FilmtoneExportPanel:199-208`), button label flip
   (`:277-281`), `MetricCard` (`:237`), and
   `presentToast(toastSaveSuccess, .success)`
   (`FilmtoneEditorStore:1745`). S3 save side: no edit.
3. **Real S3 gap = share success has no user-visible signal**.
   `shareOutput()` (`FilmtoneEditorStore:1752-1771`) on `completed`
   only `notice=nil; error=nil`. Cancel-vs-success indistinguishable.
   Fix: add `presentToast(strings.toastShareSuccess, .success)`; add
   `toastShareSuccess` to `FilmtoneStrings` (parity with
   `toastShareFailed:208`).
4. **Real S4 gap = `store.error` is unbound to UI**. No
   `.alert($store.error)` anywhere; only `recordingError` is bound
   (`FilmtoneRootView:67-84`). Save failure relies on red chip alone;
   export failure has no surface at all (success has
   `toastExportComplete:1657`, failure path at `:1663` only sets
   `store.error`). Fix: route `export()` and `saveToPhotos()` failures
   through `presentToast(userMessage(...), .error)`, mirroring the
   existing `toastShareFailed` pattern. No new alert binding needed.
5. **Recording-source parity**: `FilmtoneExportSession` shows no
   record-only branch in `exportVideo` (no `clip.mov` /
   `packageDirectory` special-case). Capture-package source threads
   through the same `request.sourceUri` path as Photo Library / Files.
   Sidecar provenance verification deferred to S5 owner walk; S4 alone
   doesn't depend on it.

Side-finding: `exportAndSave()` (`:1666`) is defined and localized
(`exportAndSave:131`) but **unused by any view**. Out of scope for M9
(don't wire, don't delete — no orphan churn).

**Revised S2-S4 surface**:
- S2 → no-op (already wired). Skip directly to S3.
- S3 → add `toastShareSuccess` string + 1-line
  `presentToast(strings.toastShareSuccess, .success)` in
  `shareOutput()` `completed == true` branch.
- S4 → add `presentToast(userMessage(...), .error)` to two failure
  catches (`export()` `:1663`, `saveExportResultToPhotos` `:1747`).

## Acceptance

Owner-visible on iPhone 17 Pro / iOS 26.4.2:

- Owner records, applies a Preset, exports, taps the **primary** Save
  CTA, sees a localized "saved to Photos" confirmation, and exits the
  flow without confusion about where the artifact landed.
- Share path remains available as the secondary CTA and reaches a
  share sheet without state corruption.
- Recording-derived export result is treated identically to a Photo
  Library / Files source export in the editor / export panel.
- A failure on any of the three (export / save / share) raises a
  localized message instead of silent swallow.

## Done conditions

1. Acceptance above observed by owner on iPhone 17 Pro / iOS 26.4.2.
2. record → editor → preset → export → save/share is one continuous
   product flow on a recording-derived source.
3. Save (Photos) is the unambiguous primary post-export CTA; Share is
   the secondary CTA.
4. The user can answer "where did the artifact land?" without
   guessing.
5. No new silent failure path for export / save / share.
6. No regression in Photo Library / Files source flows or the M8
   recording-input loop.
7. No React/Capacitor file is touched.
8. No strategy doc rewrite beyond the single Completion Log line and
   the M9 milestone block.

## Rollback plan

If S5 acceptance fails, isolate the failing step and revert the
smallest commit that introduced it. M8 (`6bc3eda0`) and Lane A
(`0448c484`) on main remain untouched on rollback.

## Preconditions

M8 + Lane A (`6bc3eda0` merge + `0448c484` Lane A) are on main as of
2026-05-08. M9 implementation branches fresh off post-merge main; do
not extend the closed M6 worktree branch.

## Outcome

S5 owner walk on iPhone 17 Pro / iOS 26.4.2 (2026-05-08) confirmed the
single acceptance criterion: 録画した動画を迷わず保存または共有できる。
record → edit → preset → export → save 一周通った。

Implementation summary (commit `138ac7ba` on
`worktree-feature+ios-m9-recording-export-completion`):

- S1 read-only sweep showed the panel CTA hierarchy (Save primary,
  Share secondary), save-success destination feedback (chip + button
  flip + MetricCard + `toastSaveSuccess`), and recording-source
  export parity already existed. No changes needed there.
- S2 deleted (CTA hierarchy already correct).
- S3 added `toastShareSuccess` ("共有しました" / "Shared") +
  `filmtone.toast.share.success` xcstring; emit on
  `shareOutput()` `completed == true`.
- S4 routed `export()` and `saveExportResultToPhotos` failures
  through `presentToast(userMessage(...), .error)` (mirrors the
  existing `toastShareFailed` pattern, no new UI binding).

Out-of-scope-for-M9 polish noted during the walk is deferred to a
separate UI/UX polish lane — this lane was scoped to the 出口可視化
gap, which closed.
