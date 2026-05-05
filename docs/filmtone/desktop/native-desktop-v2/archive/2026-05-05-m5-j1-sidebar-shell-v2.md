# M5-J1 v2 — Editing Sidebar Shell

- Milestone: M5-J (Editing chrome polish)
- Branch: `feature/native-desktop-m5-j1-sidebar-shell-v2`
- Base: `feature/native-desktop-m5-i-integration` @ `ca9acea6`
- Started: 2026-05-05 JST
- Completed: 2026-05-05 JST

## Goal

右編集パネルが画面下端で切れる問題を直し、旧 Desktop と同様に右レール
を **開閉式 sidebar** にする。`RootWindowView` の `ZStack(alignment:
.topTrailing)` 直下に直接積んでいた 5 panel スタックを `EditorSidebar`
に切り出し、上下の chrome (macOS 26 unified toolbar / 浮遊 VideoScrubBar)
との overlap を排除する。preview / media を覆い隠しすぎないよう、固定幅
+ 4/8px grid に揃える。

## Edit targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
  (新規)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  (3 surgical edit)
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
  (4 セクション登録、UUID は次の空きスロット A3C/B3B)

## Read-only references

- M5-I.3 8px grid (右レール `padding 16/16` + `cornerRadius 16` +
  container `spacing 16`) — `RootWindowView.swift:42..107`
- M5-I.2 AVPlayer route + `VideoCompositionRefreshKey` —
  `RootWindowView.swift:144..154, 547..566`
- M5-I.4a window/aspect resize 一式 — `RootWindowView.swift:264..432`
- iOS canonical Localizable は L10n を踏襲 (新規 string は不要、`Open` /
  `Export` toolbar の慣行を follow)

## Checklist

- [x] `active.md` 作成 (このファイル)
- [x] `EditorSidebar.swift` 新規 (320pt 固定幅、`GlassEffectContainer
      (spacing: 16)` + `ScrollView(.vertical)` + 5 panel)
- [x] `RootWindowView.swift` edit 1: `@AppStorage("editorSidebarOpen")`
      を `exportCoordinator` 直後に追加
- [x] `RootWindowView.swift` edit 2: inline 5-panel `GlassEffectContainer`
      ブロックを `if sidebarOpen { EditorSidebar(...) .padding(.top, 72)
      .padding(.bottom, 120).padding(.trailing, 12) }` に置換
- [x] `RootWindowView.swift` edit 3: Toolbar の Export 直後に
      `sidebar.right` toggle item (`⌘\` shortcut, `.buttonStyle(.glass)`,
      `.filmtonePointingHandCursor()`) を追加
- [x] `pbxproj` に EditorSidebar.swift を 4 セクション登録 (A3C/B3B)
- [x] M5-I 変更を 0 line も触らない
      - `PreviewSurface(... onOpenRequested:)`
      - `.ignoresSafeArea(.container, edges: .all)`
      - `hostingWindow` / `WindowAccessor` / `resolveWindow` /
        `configureWindowForTransparentGlass`
      - `resizeWindowToSourceAspect` 一式
      - `VideoCompositionRefreshKey` + `.onChange`
      - 動的 `minimumContentSize` / `.frame(minWidth:minHeight:)`
      - `VideoScrubBar` (`FilmtoneGlassSlider` + `seekVideo` +
        `isScrubbing` + `PlaybackRateMenu`)
      - Open/Export toolbar の `.buttonStyle(.glass)` /
        `.glassProminent` + `.filmtonePointingHandCursor`
      - `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`
- [x] `bun run verify:macos` PASS — `** BUILD SUCCEEDED **`
- [x] `bash apps/filmtone-desktop-macos/Verify/run.sh` PASS — 65/65 passed, 0 failed
- [x] `git diff --check` clean
- [x] active → `archive/2026-05-05-m5-j1-sidebar-shell-v2.md`
- [x] `strategy.md` Completion Log に 1-3 行追記
- [x] commit (push 不要)

## Changed files (4)

```
M  apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj
M  apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift
?? apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift
?? docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-m5-j1-sidebar-shell-v2.md (this file)
```

## Operation

- Default open。`@AppStorage("editorSidebarOpen")` で source 切替 / app
  relaunch を跨いで保持。
- Toolbar `sidebar.right` button または `⌘\` で開閉。`.keyboardShortcut`
  はメインメニュー経路なので focused TextField / NSOpenPanel sheet が
  shortcut を吸収し、text input / save prompt 操作中に sidebar が誤動作
  しない。
- Collapsed 時も Open / Export / sidebar reopen の 3 toolbar item は
  常時可視 (collapsed 時の reopen 導線確保が done 条件 3)。

## Visual smoke (next step, on user side)

1. Launch → sidebar 表示で起動 (`sidebarOpen = true` default)。Open で
   media 読込 → 5 panel が toolbar / scrub bar に被らず収まる。
2. Toolbar の `sidebar.right` button または `⌘\` で sidebar 開閉。
   collapsed 時は preview が full window 幅を使用。
3. 縦長の panel stack でも sidebar 内 ScrollView で吸収、window
   下端で切れない。
4. Source 切替 (image → video → image) を跨いでも `sidebarOpen` 状態
   保持。app relaunch でも保持。
5. Open / Export / Sidebar toggle 3 button が glass posture + cursor で
   一貫して見える。

## Hand-off to coordinator

このアーカイブと
`git diff feature/native-desktop-m5-i-integration..feature/native-desktop-m5-j1-sidebar-shell-v2`
で merge してほしい。canonical `filmtone-native-desktop-plan/.../
strategy.md` の Completion Log は M5-J1 / J2 / J3 をまとめてから 1-3 行
で書くのが安全 (本 worktree の `strategy.md` には 1 行追記済み)。

UUID 衝突回避メモ: 旧 J1 案で計画した `A37/B36` は M5-I.1 で
`FilmtoneDesktopStrings.swift` に再割当済みのため避け、`A3C/B3B` を
EditorSidebar.swift に使用。

## Verification

```bash
bun run verify:macos
bash apps/filmtone-desktop-macos/Verify/run.sh
git diff --check
```

## Done conditions

1. 右レールが window 下端で切れない (源 5 panel + 縦長 source state でも
   sidebar 内 ScrollView で吸収)。
2. Default open。`⌘\` または toolbar `sidebar.right` button で開閉、
   `@AppStorage` で source 切替 / app relaunch を跨いで状態保持。
3. Collapsed 時は preview が full window 幅、Open / Export / sidebar
   reopen の導線が toolbar に残る。
4. Verify 65/65 PASS、xcodebuild Debug ✅、`git diff --check` clean。
5. M5-I 統合済 11 surface (上記 list) を 0 line も touch していない。

## Stop conditions

- Done 条件 5 (M5-I 保持) を満たせない場合 — 即停止 + report。
- Verify failure 3 連続 — 即停止 + report。
- Scope 拡張要求 (compare = J2 / slider = J3 触らない) — 即停止 + report。

## Out of scope

- Compare implementation (M5-J2 worker scope)。`EditorSidebar` の
  `exportCoordinator` 引数のような将来 hook 余地のみ確保。
- Slider visual / AVPlayer / Dual LUT (M5-J3 / 他 lane)。
- Canonical `filmtone-native-desktop-plan/.../strategy.md` の Completion
  Log への追記 (本 worktree の `strategy.md` に 1-3 行記入のみ。canonical
  への propagate は coordinator 統合後)。

## Unexpected

(none yet)
