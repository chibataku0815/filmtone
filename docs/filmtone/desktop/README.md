# Filmtone Desktop Docs

This directory keeps current Desktop routing small. Historical handoffs and
superseded Native Desktop v2 phase plans live under `archive/`.

Desktop means the native macOS app. The current implementation lives in
`apps/filmtone-desktop-macos/`, and Native Desktop v2 owns the public Desktop
release rail. `apps/desktop-film-lab-batch/` is legacy Electron code and should
only be opened when a task explicitly says legacy Electron, old Desktop, or
rollback.

## Current Entry Points

- Official Desktop app:
  `../../../apps/filmtone-desktop-macos/`
- Native Desktop v2 strategy:
  `native-desktop-v2/strategy.md`
- Native Desktop v2 current task:
  `native-desktop-v2/active.md` if present. If it is missing, no Native
  Desktop v2 subtask is currently open.
- Native Desktop v2 completed task logs:
  `native-desktop-v2/archive/`
- Historical release-cutover record:
  `release-cutover/README.md`
- Historical Mac App Store readiness record:
  `mac-app-store-readiness/README.md`

## Historical Docs

- Early Native Desktop v2 phase plans and handoffs:
  `archive/native-desktop-v2-legacy-2026-05-03/`
- Older Desktop handoffs and superseded plans:
  `archive/legacy-handoffs-2026-04-25-to-2026-05-03/`

Before stating current release truth, run the life truth scripts. Do not infer
current state from archived handoffs.
