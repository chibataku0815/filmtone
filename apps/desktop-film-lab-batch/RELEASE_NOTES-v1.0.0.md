# Filmtone Desktop v1.0.0

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> v1.0 is a color-quality milestone. The interactive preview now runs on a
> WebGPU backend with a wider internal working space, so highlights hold their
> shape instead of clamping to the edge of sRGB. No visible feature was
> removed at the product surface — this is the quiet foundation release before
> the cross-filter work lands in v1.1.

### Wider internal working space (Linear Rec.709, no clamp)

The preview pipeline now runs in `rgba16float` linear Rec.709 end-to-end.
Highlight values above 1.0 survive grading, LUT shaping, and film post
instead of being crushed on the way to the screen. The final display transform
is a hardware sRGB OETF, so what you see is still sRGB — the difference is
that the signal that led to it is much cleaner.

- LUT2 receives signal through a Reinhard soft-shaper, so creative LUTs now
  see a well-behaved 0..1 input even when the grade runs hot.
- `pow` / `log` / `sqrt` call sites are guarded with `max(x, 0.0)` so no-clamp
  negative excursions cannot poison the pipeline.

### WebGPU preview backend, WebGL fallback retained

The Electron preview now asks for a WebGPU adapter first and falls back to
WebGL2 silently if the adapter is unavailable. On Apple Silicon (adapter
`apple / metal-3`) the feature set is complete — color, grain, bloom,
halation, motion blur, and composite all run on the WebGPU path.

- Linear Rec.709 + `rgba16float` working space, `rgba8unorm-srgb` swapchain
  (hardware OETF), `colorSpace: 'srgb'` / `alphaMode: 'opaque'` canvas.
- Identity 3D LUT pre-uploaded at startup — grading uniforms always have a
  valid LUT1 binding even before a user `.cube` is loaded.
- 256² blue-noise grain tile (no hash-based noise), pre-baked and tiled via a
  repeat sampler to keep the tiling invisible.
- Motion blur ring buffer is a single GPU texture with `depthOrArrayLayers = 8`
  and a `validSlots` uniform, so the first eight frames are accumulated
  correctly without a cold-start flash.

### WebGL2 path unchanged for web and export

The apps/web preview stays on WebGL2 by design (the WebGPU backend is
dynamically imported and tree-shaken from the web bundle). Video export and
batch export also continue to run on WebGL2 for this release — the WebGPU
`GpuRenderer` that these paths need will land in v1.1.

## Known limits (v1.0)

- Cross-filter streaks (peak / peak-spacing / streak / blend) are
  compile-validated in the WebGPU backend but not yet wired into the render
  graph at runtime. All v1.0 factory presets ship with `crossFilterStrength: 0`,
  so the visible output is identical to v0.6.x for every factory preset. User
  presets with `crossFilterStrength > 0` saved from v0.6.x will render as if
  cross-filter is off until v1.1.
- Hard-mode cross-filter temporal accumulation stays deferred to v1.1 (no
  change from v0.6.x).
- Video export and batch export run on the WebGL2 backend for v1.0. The
  headless WebGPU renderer (`GpuRenderer`) and the nv12 / PNG export integrations
  ship in v1.1.
- HDR / P3 output is v2.0 scope (canvas stays `colorSpace: 'srgb'` for v1.x).

## Compatibility

- macOS 11+ arm64, Electron 32.x.
- If WebGPU bootstrap fails (adapter / device request rejected), the preview
  silently falls back to WebGL2. The output will match v0.6.x in that case;
  only the internal working space drops back to 8-bit sRGB.

## Recent lineage

- **v0.6.2 → v1.0.0**: WebGPU preview backend, `rgba16float` working space,
  no-clamp primary grade, Reinhard soft-shaper in front of LUT2, hardware sRGB
  OETF final transform. Apps/web, video export, and batch export stay on
  WebGL2 for this release.
- **v0.6.1 → v0.6.2**: Cross Filter product-surface cleanup (Soft frozen,
  Spikes discrete 4/6/8).
- **v0.6.0 → v0.6.1**: Preview recovery after export, launch-time update
  banner restored, glow retuned for night scenes, hard cross-filter spacing
  corrected.
- **v0.5.1 → v0.6.0**: Cross Filter optical effect, compare / playback
  polish, persistent local proxy cache.
- **v0.5.0 → v0.5.1**: Instant preview for heavy footage, eight-frame motion
  blur ring, portrait video framing, split / motion-blur fix.
- **v0.5.0**: Grain rebuild, new Diffusion effect, preset recalibration.

## Checksums

```text
a859448905cf2252690937cd199fbf85132f05a3435920b770b9cd5b77030e72  filmtone-1.0.0-arm64.dmg
```

(Unsigned / ad-hoc codesign — the signed + notarized release will regenerate
this DMG via `bun run dist:mac:release` and the checksum will change.
Previous unsigned DMG SHA was `8cfd1734…`; this rebuild applies the WebGPU
canvas-config spec fix + fallback removal — see `docs/webgpu-migration/v1.0-qa-blocker-handoff.md` §8.)
