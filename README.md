# Filmtone

Standalone product monorepo for Filmtone Desktop, Filmtone iOS, and the shared film-lab packages that keep color, preset, Swift generation, and export parity in one place.

Desktop means the native macOS app in `apps/filmtone-desktop-macos`. The
Electron app in `apps/desktop-film-lab-batch` is a frozen legacy rail for
explicit legacy or rollback work only.

## Primary Surfaces

- `apps/filmtone-desktop-macos` - official macOS Desktop app.
- `apps/desktop-film-lab-batch` - legacy Electron Desktop app, frozen/reference
  only unless a task explicitly targets the old rail.
- `apps/capacitor-film-lab-ios` - iOS app shell and native export pipeline.
- `apps/filmtone-resolve-ofx` - DaVinci Resolve OFX plugin (C++/Metal); design lane in `docs/filmtone/davinci-plugin/`.
- `packages/film-lab-core` - shared color, schema, preset, LUT, and Swift payload logic.
- `packages/film-lab-renderer` - WebGL/WebGPU renderer.
- `packages/film-lab-ui` - shared UI surface.
- `packages/film-lab-smart-look` - smart look package.
- `packages/film-lab-swift-core` - shared Swift runtime core.
- `packages/film-lab-codex-mcp` - batch automation MCP server.

Full structure, responsibilities, generated regions, and per-surface verify
commands: [`docs/filmtone/filmtone-codemap.md`](docs/filmtone/filmtone-codemap.md).
User-facing feature coverage: [`docs/filmtone/filmtone-feature-matrix.md`](docs/filmtone/filmtone-feature-matrix.md).

## Core Commands

```bash
bun install
bun run build:core
bun run build:renderer
bun run verify:desktop
bun run verify:legacy-desktop
bun run verify:ios
```

Desktop and iOS use root `messages/{en,ja}.json` and root `public/` assets. Portfolio web remains the public landing, support, privacy, and release-notes surface.
