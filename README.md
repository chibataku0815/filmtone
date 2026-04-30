# Filmtone

Standalone product monorepo for Filmtone Desktop, Filmtone iOS, and the shared film-lab packages that keep color, preset, Swift generation, and export parity in one place.

## Workspaces

- `apps/desktop-film-lab-batch` - macOS Desktop app.
- `apps/capacitor-film-lab-ios` - iOS app shell and native export pipeline.
- `packages/film-lab-core` - shared color, schema, preset, LUT, and Swift payload logic.
- `packages/film-lab-renderer` - WebGL/WebGPU renderer.
- `packages/film-lab-ui` - shared UI surface.
- `packages/film-lab-smart-look` - smart look package.

## Core Commands

```bash
bun install
bun run build:core
bun run build:renderer
bun run verify:desktop
bun run verify:ios
```

Desktop and iOS use root `messages/{en,ja}.json` and root `public/` assets. Portfolio web remains the public landing, support, privacy, and release-notes surface.
