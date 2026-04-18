# Filmtone iOS Phase 0 — Device Checklist (Phase B gate)

Single-page checklist. Consult this while tapping through exports; everything else (rules, schema, decision thresholds) is already wired.

Anchor: `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/2026-04-18-filmtone-ios-phase0-phase-a-complete-phase-b-gate-handoff.md`

## 0. Launch

From worktree root:

```sh
bun run open:ios-phase0
```

Xcode opens → select connected device → Run.

Only supported app path: `apps/capacitor-film-lab-ios`.
Only supported workspace: `apps/capacitor-film-lab-ios/ios/App/App.xcworkspace`.

## 1. Run matrix (最小)

**1 run だけ**。60s (S1II → H.264 tripod) を 1 回書き出す。3 分。

- 60s は aggregator の唯一の閾値クリップ。これで Go/No-Go が決まる。
- 5min / short は 1 run の結果が中間 Go (1.8-2.5x) に入った時 **だけ** 追加。先回りしない。
- Strong-Go (≤2.0x) or 明確 No-Go (>2.5x) なら 1 run で判断確定。

## 2. The three fixed clips (photo-ops lens)

| Bucket | Clip | Spec | Purpose |
| --- | --- | --- | --- |
| short | iPhone internal HEVC | 4K30 / 15–30s / handheld walk | RS + high-bitrate stress |
| standard (gate anchor) | LUMIX S1II → H.264 | 1080p30 / ~60s / tripod | official 60s gate |
| upper | existing 4m29s clip | 1280×720 avc1 | 5min cap stability |

Name clips `clip-60s-take1.mov` / `clip-5min-take1.mov` / `clip-short-take1.mov` etc. — the `60s` / `5min` substring drives bucketing.

## 3. Per-run 5 taps

1. Pick source
2. Apply preset + dual LUT (LUT1 "Camera Profile" ON, LUT2 "Film Look" — defaults from `cinematic`)
3. `書き出しを実行` → wait for completion
4. After save, tap `Pass` / `Fail` / `未確認` in the export sheet (visual floor: start / middle / end spot-check)
5. Tap `ベンチ結果を共有` → the 1-line markdown row goes to clipboard (or share sheet)

## 4. Drop the row on Mac

Option A (fastest — one command):

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0
bun run bench:append
```

Reads the Mac clipboard (AirDropped / copied row) and appends to `benchmark/runs/auto.md`, creating the header if the file does not exist.

Option B (manual): paste into `benchmark/runs/<date>-<device>-<clip>.md`. Header lines (`| date |…`) and dividers (`| --- |…`) are ignored by the parser.

## 5. Aggregate → decision line

row 追記した直後に:

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0
bun run bench
```

First line is the decision:

| Decision | Condition | Next |
| --- | --- | --- |
| **Strong-Go** | 60s avg ≤ 2.0x AND 100% visual pass AND 100% save ok | Phase C auto-proceed (see runbook) |
| **Go** | 60s avg ≤ 2.5x AND visual fail < 10% | ask user once: "invite 5 testers Y/N?" |
| **No-Go** | otherwise | stop; focus on Desktop |

Exit codes: `0` Strong-Go/Go, `3` No-Go, `2` empty dir.

## 6. If Strong-Go

Follow `docs/guides/2026-04-18-filmtone-ios-phase0-phase-c-auto-runbook.md` on life side. Two commands, no thinking.

## 7. What counts as a pass (visual floor)

- No black / stuck frames at start, middle, end
- Save to Photos completes
- Color roughly matches preview (subjective; cinematic should read as cinematic)
- No permission dead-end

If any of the above fails → `Fail`. If unsure → `未確認` (counts as unchecked, not fail).

## 8. Do NOT

- Re-verify Phase A (build / dual-LUT compile / 4K cap / save-to-Photos — all settled)
- Touch UIScene / warning cleanup / App Store metadata / Metal — Phase Polish only
- Bundle `.cube` assets (see `src/presets/luts/README.md` for the intended path)
- Push the worktree branch or merge to main until Phase C auto-runbook says so
