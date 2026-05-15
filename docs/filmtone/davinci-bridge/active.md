# DB-M13 DRX-first Approximate Imported Grade

Milestone: DB-M13

Goal: DaVinci Bridge の `DRX import -> Imported Grade library -> grade resolution -> preview/export/sidecar -> Verify` を Desktop 全体掃除ではなく縦断 feature boundary として復元する。

Edit targets:

- `packages/film-lab-core/src/imported-grade-look.ts`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/`
- `apps/filmtone-desktop-macos/Verify/`

Read-only references:

- `apps/filmtone-desktop-macos/README.md`
- `docs/filmtone/desktop/README.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

Checklist:

- [x] Imported Grade schema and TS validation surface.
- [x] Swift Imported Grade schema, evaluator, store, and package import.
- [x] DRX XML/body/protobuf graph importer with approximate graph-only path.
- [x] Single `FilmtoneGradeResolution` model for built-in and Imported Grade sources.
- [x] `FilmtoneGradeSelection` / `FilmtoneGradeRecipe` value pipeline for built-in and Imported Grade sources.
- [x] Still preview, video composition, still export, video export, and sidecar consume the resolved model.
- [x] Preview, video composition refresh, export requests, and sidecar payloads pass the grade recipe instead of re-resolving grade fields independently.
- [x] Imported Grade library controls wired into the Desktop sidebar.
- [x] `Verify/main.swift` split into feature harness files.
- [x] DB-M13 GradeResolution and DRX tests added to Verify.
- [x] Verification completed.

Verification:

- [x] `bun test packages/film-lab-core/src/imported-grade-look.test.ts` — 4/4 pass.
- [x] `bun run build:core` — pass.
- [x] `bash apps/filmtone-desktop-macos/Verify/run.sh` — 143/143 pass.
- [x] `bun run verify:desktop` — pass.
- [x] `git diff --check -- packages/film-lab-core apps/filmtone-desktop-macos docs/filmtone/davinci-bridge` — pass.

Done conditions:

- Imported Grade can be represented, selected, resolved, previewed, exported, and serialized without each surface inventing its own grade resolution.
- DRX graph-only import remains explicitly approximate and does not claim Resolve parity.
- Verify harness no longer has a single 3000+ line `main.swift`.

Stop conditions:

- Done conditions met.
- Unexpected scope conflict with existing dirty worktree.
- 3 consecutive failures on the same verification command.

Out of scope:

- Broad Desktop UI cleanup unrelated to import / preview / export quality.
- Release copy or App Store claim changes.
- Full Resolve parity claims for DRX internals.

Unexpected:

- Clean `main` did not contain the earlier DB-M13 files, so the full vertical slice was reapplied rather than only the last Verify split.
- The first `verify:desktop` pass after recipe extraction exposed stale optical arguments on `FilmtoneDesktopVideoRenderInputs`; optical selection and intensity now live inside `FilmtoneGradeRecipe`, while session-owned camera optics remains the only video-input patch.

Copy / History Impact:

- No copy/history impact: internal architecture and import/export behavior only; no public parity or release claim changed.

Article Opportunity:

- Developer note

Change-History Opportunity:

- Yes: this records why DaVinci Bridge work moved from a large Desktop cleanup into a DB-M13 vertical architecture recovery.

Article foundation: `なし`

## Implementation Capture

- 動機:
  DaVinci Bridge の品質に直接効く `DRX import -> resolution -> preview/export/sidecar` が複数箇所に分散しており、`main.swift` の肥大化も含めて DB-M13 の進行を妨げていたため。

- 解決したいこと:
  Imported Grade の解釈、LUT 解決、sidecar payload 生成、preview/export の grade 解決がそれぞれ別々の責務として読めない状態を変える。

- 解決方法:
  Imported Grade schema/store/importer、DRX importer、`FilmtoneGradeResolution`、Imported Grade UI、Verify feature harness を大きめの feature boundary として追加した。さらに `FilmtoneGradeSelection` / `FilmtoneGradeRecipe` を入れて、preview / video composition / still export / video export / sidecar が built-in / Imported Grade / Quick / override / optical state を 1 つの recipe から解決するようにした。

- ブロッカー:
  Clean `main` に前回の DB-M13 差分が残っていなかったため、直近の `main.swift` 分割だけではなく、Core / Swift runtime / UI / export まで全体を再反映する必要があった。recipe 化後の最初の Xcode build で、動画 preview input に旧 optical 引数が残っていることも判明した。

- 驚き / 違和感:
  既存の preview/video/export は同じグレードを扱っているように見えて、creative LUT と optical patch の解決タイミングが面ごとに違っていた。video composition refresh key も Imported Grade の同一性を十分に含んでおらず、UI 変更時の再描画境界として弱かった。
