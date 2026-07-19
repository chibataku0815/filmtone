# Filmtone Feature Matrix — 機能表（全機能網羅の目視検証用）

Last updated: 2026-07-19 JST（codemap-feature-audit lane）

## これは何か

Filmtone の **user-facing capability（機能）** をカテゴリ別に列挙し、どの
サーフェスが提供するかを一覧する目視検証用の表。「全機能が網羅できているか」を
人が走査して確認するための成果物。内部 helper は行にしない。挙動・数値の現行
仕様は各 source / lane doc を正本とする（本表は網羅確認の地図）。

## サーフェス凡例

| 記号 | サーフェス |
|---|---|
| **Core** | `packages/film-lab-core`（kernel: 機能を支える math/data/catalog） |
| **iOS** | `apps/capacitor-film-lab-ios`（native SwiftUI + AVFoundation） |
| **Desk** | `apps/filmtone-desktop-macos`（native macOS Desktop） |
| **OFX** | `apps/filmtone-resolve-ofx`（DaVinci Resolve OFX plugin） |
| **Web** | web rail: `film-lab-ui` + `film-lab-renderer` + legacy Electron `desktop-film-lab-batch` |
| **MCP** | `packages/film-lab-codex-mcp`（batch automation server） |

`✓`=提供 / `—`=非対象（監査/grep で非提供確認） / `?`=未確定（要目視） /
`⚙︎`=kernel が data/contract を供給。

## 1. Source / Capture（取り込み・撮影）

| 機能 | Core | iOS | Desk | OFX | Web | MCP |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Camera capture（record） | — | ✓ | — | — | — | — |
| Still / Video open（source import） | — | ✓ | ✓ | — | ✓ | ✓ |
| DRX / Imported Grade import | ⚙︎ | — | ✓ | (contract) | — | — |
| Capture-package adopt | — | ✓ | ✓ | — | — | — |
| Camera source profiles（Apple Log / ARRI / Sony S-Log3 → Rec.709） | ⚙︎ | ✓ | ✓ | — | ✓ | — |

## 2. Look / Preset

| 機能 | Core | iOS | Desk | OFX | Web | MCP |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Presets（grade foundation catalog） | ⚙︎ | ✓ | ✓ | — | ✓ | — |
| Creative Pack 01 Looks（Stone / Urban） | ⚙︎ | ✓ | ✓ | — | ✓ | — |
| Source-aware Look Director | ⚙︎ | ✓ | ✓ | — | ✓ | — |
| Look-ID / preset versioning | ⚙︎ | — | — | — | — | — |
| Saved Look library | — | — | ✓ | — | — | — |
| Smart Look（AI grade-delta） | ⚙︎ | — | — | — | ✓ | — |

## 3. Grade / Adjust

| 機能 | Core | iOS | Desk | OFX | Web | MCP |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Primary grade pipeline | ⚙︎ | ✓ | ✓ | ✓ | ✓ | — |
| Advanced param adjust（param overrides） | ⚙︎ | ✓ | ✓ | — | ✓ | — |
| Quick adjust / QuickState | ⚙︎ | ✓ | ✓ | — | — | — |
| Compare split / A-B | — | ✓ | ✓ | — | ✓ | — |
| Histogram | — | — | — | — | ✓ | — |

## 4. Optics / Finish

| 機能 | Core | iOS | Desk | OFX | Web | MCP |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Lens softness | — | ✓ | — | ✓ | — | — |
| Deep glow / bloom-halation | ⚙︎ | ✓ | ✓ | ✓ | ✓ | — |
| Vignette | ⚙︎ | ✓ | ✓ | ✓ | ✓ | — |
| Peripheral chromatic shift | — | ? | — | ✓ | — | — |
| Texture / detail softness | ⚙︎ | ✓ | ✓ | ✓ | ✓ | — |
| Film breath | ⚙︎ | ✓ | ✓ | ✓ | — | — |
| Gate weave | — | — | — | ✓ | — | — |
| Film damage（dust / scratch / grain） | ⚙︎ | ✓ | ✓ | ✓ | ✓ | — |
| Optical filters（Black Mist / Cine Bloom / Pearl Glow / streak / Halo Prism / Backlight Veil） | ⚙︎ | ✓ | ✓ | — | ✓ | — |
| Cross filter / light shafts | — | — | — | — | ✓ | — |
| Film compression v3 | ⚙︎ | ✓ | ✓ | — | ✓ | — |
| Shadow latitude | ⚙︎ | ✓ | ✓ | — | — | — |
| Split tone | ⚙︎ | — | ✓ | — | ✓ | — |

## 5. LUT

| 機能 | Core | iOS | Desk | OFX | Web | MCP |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| .cube parse + 2D pack | ⚙︎ | — | ✓ | — | ✓ | — |
| LUT / custom LUT editor（3D LUT） | — | ✓ | ✓ | — | ✓ | — |

## 6. Export

| 機能 | Core | iOS | Desk | OFX | Web | MCP |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Still export + sidecar | ⚙︎ | ✓ | ✓ | — | — | — |
| Video export + sidecar | ⚙︎ | ✓ | ✓ | — | ✓ | — |
| Highlight-reel export | — | ✓ | ✓ | — | — | — |
| Export parity geometry | ⚙︎ | ✓ | ✓ | — | ✓ | — |
| Mezzanine routing | — | ✓ | — | — | — | — |
| Batch automation export（social1080 / archiveH264） | — | — | ✓(CLI) | — | — | ✓ |
| ExportActivity share extension（Live Activity） | — | ✓ | — | — | — | — |

## 7. Video

| 機能 | Core | iOS | Desk | OFX | Web | MCP |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Playback / transport | — | ✓ | ✓ | — | ✓ | — |
| Scrub thumbnails / filmstrip | — | — | ✓ | — | ✓ | — |
| Video timing（output vs conform fps / 24fps Slow Mode） | ⚙︎ | ✓ | ✓ | — | — | — |
| Stabilization / Gyroflow | — | ✓ | — | — | — | — |

## 8. Platform / Infra

| 機能 | Core | iOS | Desk | OFX | Web | MCP |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| MCP batch automation server | — | — | — | — | — | ✓ |
| Resolve OFX host（Metal compute） | — | — | — | ✓ | — | — |
| WebGL2 / WebGPU render backends | — | — | — | — | ✓ | — |
| Swift payload generation（kernel → Swift/C++） | ⚙︎ | (consume) | (consume) | (consume) | — | — |

## Coverage / 目視確認メモ

- **確度**: `✓` は各サーフェス監査で確認した提供。iOS の疑義行は source grep で
  確定済み（2026-07-19）: **Lens softness = ✓**（`Strings/FilmtoneStrings.swift` +
  `Source/FilmtonePhase0Math.swift` に native 実体）; **Histogram / Split tone /
  Gate weave / Scrub filmstrip = 非提供**（native hit ゼロ。`ios/App/App/public/
  assets/*.js` の hit は purged web bundle の残置で native 機能ではない）;
  **Peripheral chromatic shift = `?`**（`chromatic` の native hit は
  source-profile chromatic adaptation の可能性があり、optics module としては未確定
  → user 目視で確定）。
- **spotted（別件・要確認）**: `apps/capacitor-film-lab-ios/ios/App/App/public/
  assets/` に旧 web renderer（WebGPUBackend / index）の js bundle が残置。native
  SwiftUI 化後の残骸か Capacitor shell の意図的同梱か未確定。本表の機能判定には
  含めていない（native 機能ではないため）。
- **OFX 8 モジュール**（Lens softness / Deep glow / Vignette / Peripheral chromatic
  shift / Texture softness / Film breath / Gate weave / Film damage）は resolve-ofx
  監査で全数存在を確認済み。
- **rail の非対称は仕様**: Gate weave / Peripheral chromatic shift / Lens softness は
  現状 OFX 専用。native（iOS/Desktop）optics は Metal 実装、web は WebGL/WebGPU。
- 未確定・gap 候補は codemap `Refactor Findings` とは別に、本表の `—` を user が
  目視して確定する。
