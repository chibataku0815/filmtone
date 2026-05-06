# Filmtone iOS Meta Before/After Ad - DaVinci Handoff

Date: 2026-05-06 JST

This handoff preserves the current conversation state for a new chat. The next
chat should support concrete DaVinci Resolve operations for creating
Facebook/Instagram Before/After ad material for Filmtone iOS. It should not
continue copywriting unless the user explicitly asks for copy help again.

## Current User Goal

The user wants to start increasing Filmtone iOS users.

The current active work item is:

- Create more Before/After material.
- First target: Facebook and Instagram advertising creative.
- The user specifically wants practical DaVinci Resolve operation support.
- The user will write the ad wording themselves.

The following items are intentionally out of scope for this chat and will be
handled elsewhere:

- Custom Product Pages in App Store Connect.
- Small Apple Ads / Apple Search Ads research and setup.

## Repository And Product Context

Repository:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Relevant app surface:

```text
apps/capacitor-film-lab-ios/
docs/filmtone/ios/
```

Follow the repository rules in `AGENTS.md`:

- For iOS work, start from `apps/capacitor-film-lab-ios/CLAUDE.md`.
- Before stating public iOS version, local candidate, App Store state, or
  release scope, run:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

- Keep public App Store state and local implementation state separate.
- Do not stage, commit, push, or bump portfolio submodule unless the user
  explicitly asks.
- Do not revert user changes.

Latest checks in this conversation:

- `git status --short --branch` on 2026-05-06 14:10 JST:

```text
## main...origin/main [ahead 34]
```

- Latest iOS truth script on 2026-05-06 14:10 JST reported:

```text
branch/head: main @ 9053cf98
commits_ahead_of_upstream: 34
commits_behind_upstream: 0
xcode_marketing_versions: 1.5
xcode_build_versions: 4
ios_deployment_targets: 26.0
public_trackName: Filmtone - iPhoneでフィルムの世界観へ
public_bundleId: com.chibatakumi.film.lab.ios
public_version: 1.4
public_minimumOsVersion: 26.0
public_formattedPrice: 無料
public_primaryGenreName: Photo & Video
```

Important: an earlier truth-script run in the same conversation reported public
version `1.5`, but the latest run reported public version `1.4`. Treat this as
temporally unstable App Store truth. The next chat must rerun the truth script
before stating any public version.

Local iOS commits not in upstream from the latest truth script:

```text
9053cf98 docs: archive legacy filmtone handoffs
2f2281b5 chore(ios): refresh app store metadata
774085dc fix(ios): Look × Veil energy max-merge port from macOS
34b8e9c9 feat(ios): user-initiated cache release UI + low-disk proactive prune
a27d901e feat(ios): add Desktop handoff sheet for >5min videos
575a3942 feat: add marker highlight reel
```

## Filmtone Product Facts To Keep In Mind

Safe public/current product definition:

- Filmtone is an iPhone finishing app for video color / film look.
- It lets the user choose a film look, adjust strength and visual texture, compare
  Before/After, then save/share/export from iPhone.
- Current App Store metadata emphasizes:
  - film-look color,
  - Stone / Urban Creative Pack 01,
  - fullscreen editor,
  - intensity,
  - light bloom / halation / diffusion feel,
  - grain,
  - Source Profile and `.cube` LUT use,
  - Before/After confirmation,
  - saving/sharing on iPhone.

Vocabulary constraints:

- Use `動画`, not `短尺動画`.
- Use `video`, `videos`, or `footage`, not active positioning like
  `short-form video`.
- `Preset` is the curve/grade foundation.
- `Look` is reserved for Stone / Urban Creative LUT Pack context.
- Do not claim unsupported pro workflow replacement, cloud sync, broad Desktop
  parity, or unreleased state.

For this task, these vocabulary rules mostly matter for filenames, labels, and
on-screen placeholders. The user will supply final copy.

## Conversation History And Course Correction

The user asked how to increase iOS users. The first useful answer proposed:

1. Increase Before/After material.
2. Create Custom Product Pages.
3. Try small Apple Ads.

The user then selected those three lanes and clarified:

- Before/After material should start with Facebook/Instagram ads.
- Custom Product Pages will be created in another chat.
- Apple Ads will be investigated and handled in another chat.

The assistant answered that:

- 30 seconds is usable as a master or retargeting asset.
- 15 seconds should be the main Meta ad asset.
- 6 seconds can be a quick test asset.
- 9:16 vertical should be the primary format.

The assistant then attempted to write ad wording. The user rejected it strongly:

- The wording was not understandable or attractive to them.
- The user said it was just feature explanation.
- The user explicitly said they will think of the wording themselves.
- The user now wants support on another part: concrete DaVinci operation support.

This is the key instruction for the next chat:

Do not keep proposing Japanese ad copy. Support the user in DaVinci Resolve:
timeline setup, clip structure, Before/After construction, text placeholder
placement, motion, audio, export settings, QC, and iteration.

## External Platform Guidance Already Checked

Official Meta sources checked during this conversation:

- Meta video ads page:
  `https://www.facebook.com/business/ads/video-ad-format`
- Meta Reels ads page:
  `https://www.facebook.com/business/ads/facebook-instagram-reels-ads`
- Instagram Help Center on boosting Reels:
  `https://www.facebook.com/help/instagram/570215404599013?locale=en_GB`

Useful takeaways from those sources:

- Meta generally recommends a 15-second maximum for video ads.
- Reels ads should be built for mobile, preferably 9:16 vertical.
- Meta highlights better Reels performance when creative uses 9:16 video, audio,
  and keeps key messages in safe zones.
- Boosted Instagram Reels must be less than 90 seconds and use fullscreen 9:16.
- Reels with copyrighted music, GIFs, interactive stickers, or third-party camera
  filters cannot be boosted.
- Reels can be sound-on, but the creative should still work without sound.

Practical implication:

- Create a 15-second primary ad first.
- Create a 30-second master only if the user wants more room for multiple
  examples or explanation.
- Keep the first 1-2 seconds visually decisive.
- Use no copyrighted music if the asset may be boosted.

## Recommended Asset Set

Start with the smallest useful set:

```text
filmtone_meta_9x16_15s_before-after_v001.mp4
filmtone_meta_9x16_30s_master_v001.mp4
filmtone_meta_9x16_06s_snap_v001.mp4
```

Only create feed-specific versions after the 9:16 vertical versions work:

```text
filmtone_meta_4x5_15s_before-after_v001.mp4
filmtone_meta_1x1_15s_before-after_v001.mp4
```

Recommended primary format:

- 1080 x 1920.
- 9:16 vertical.
- 30 fps unless the source is clearly 24/25/60 and the user wants to preserve it.
- H.264 `.mp4`.
- AAC audio.
- SDR Rec.709 target for social delivery unless the user explicitly wants an HDR
  experiment.

## DaVinci Resolve Support Scope

The next chat should help with concrete Resolve actions such as:

- Creating the project and bins.
- Creating a 9:16 timeline.
- Importing Before and After footage.
- Matching Before/After shots by frame/action.
- Cropping/reframing horizontal footage into vertical.
- Building a hard-cut Before/After reveal.
- Building a split-screen comparison.
- Building an animated wipe reveal.
- Adding text placeholders without writing the final copy.
- Adding safe-zone guides.
- Adding music/SFX only from cleared sources.
- Exporting Meta-ready `.mp4` files.
- Performing visual QC.

The next chat should avoid:

- More ad copy brainstorming unless asked.
- App Store Custom Product Page work.
- Apple Ads setup.
- Broad repo audits.
- Code changes unless the user explicitly asks for automation/scripts.

## Suggested DaVinci Resolve Workflow

### 1. Project Setup

Create a Resolve project named something like:

```text
Filmtone Meta BeforeAfter 2026-05
```

Create bins:

```text
01_before
02_after
03_ui_or_screen_recording
04_audio
05_graphics_logo
06_timelines
07_exports
```

If footage is from iPhone HDR / Apple Log / P3, keep the social ad target simple:
make the final timeline/export SDR Rec.709 unless the user asks for an HDR
variant. If color management is unclear, do not guess final color blindly; export
a short test and check it on an iPhone in Instagram/Facebook preview context.

### 2. Timeline Setup

Create a vertical timeline:

```text
Resolution: 1080 x 1920
Frame rate: 30 fps, or match the source if there is a reason
Timeline name: META_9x16_15s_BeforeAfter_v001
```

Turn on safe area guides if available:

```text
View > Safe Area
```

Keep important text and logo away from:

- top UI area,
- bottom CTA / caption area,
- extreme left/right edges.

Use the center-safe area for all important overlays.

### 3. Recommended 15-Second Timeline Structure

Use this as structure only. The user supplies wording.

```text
00:00-00:02  Strong Before shot or split-screen opening
00:02-00:04  Immediate After reveal
00:04-00:08  Second example or quick adjustment/UI moment
00:08-00:12  Before/After comparison, preferably animated wipe
00:12-00:15  App identity + user-provided CTA
```

Important: The first frame should not be a generic logo card. Show the footage
or the transformation immediately.

### 4. Recommended 30-Second Master Structure

Use this only if the user wants a slightly fuller story:

```text
00:00-00:03  Strong Before/After hook
00:03-00:08  Example 1 transformation
00:08-00:14  Example 2 transformation
00:14-00:20  Short app/UI operation moment, if visually clean
00:20-00:26  Best transformation repeated as proof
00:26-00:30  App identity + user-provided CTA
```

The 30-second version should still be visually led. Do not turn it into a feature
walkthrough.

### 5. Hard-Cut Before/After Reveal

Use when the source and output are the same shot and can be aligned.

Operation:

1. Put the Before clip on `V1`.
2. Put the matching After clip on `V2` or directly after the Before clip on the
   same track.
3. Align the same moment by eye using the waveform/action/frame content.
4. Cut from Before to After at the strongest visual moment.
5. Add a subtle sound hit if the audio is licensed/cleared.

Use this for the first 2-4 seconds if the change is strong.

### 6. Static Split-Screen Comparison

Use when the user wants instant comparison.

Operation:

1. Put Before on `V1`.
2. Put After on `V2`.
3. Align the two clips.
4. Select the top After clip.
5. In Inspector > Cropping, crop the left side so only the right half of After is
   visible.
6. Leave Before visible underneath on the left half.
7. Add a thin vertical divider line using a Solid Color generator or simple
   graphic.
8. Add optional `BEFORE` / `AFTER` labels only if the user approves the labels.

If the source framing differs, use Inspector > Transform > Zoom / Position to
match the subject before cropping.

### 7. Animated Wipe Reveal

Use when the transformation is strong and the user wants a more ad-like reveal.

Simple Resolve approach:

1. Put Before on `V1`.
2. Put After on `V2`.
3. Align both clips.
4. Select After on `V2`.
5. In Inspector > Cropping, keyframe the crop amount so After reveals across the
   frame.
6. Add a thin vertical divider line and keyframe its X position to follow the
   reveal.

If keyframing crop is tedious, use a built-in wipe transition or Fusion mask. For
handoff accuracy, prefer the simple Inspector crop method first.

### 8. Reframing Horizontal Footage Into 9:16

Operation:

1. Put the clip on the 1080 x 1920 timeline.
2. Select the clip.
3. Inspector > Transform > Zoom until the vertical frame is filled.
4. Adjust Position X/Y to keep the subject and visual change readable.
5. Avoid black bars unless the user explicitly wants a framed layout.
6. Check the opening frame on a phone-sized preview.

For moving subjects, add simple Position keyframes rather than using aggressive
auto-reframe that may drift.

### 9. Text Placeholder Strategy

Because the user will write the wording:

- Use placeholders such as:

```text
COPY_01_HOOK
COPY_02_REVEAL
COPY_03_CTA
```

- Do not invent final copy.
- Keep placeholders short and inside safe zones.
- Use the final user-provided text only after they give it.
- Make sure text remains readable over both Before and After frames.

### 10. Audio Strategy

For ad/boost safety:

- Avoid copyrighted music.
- Use silence, cleared music, Meta Sound Collection, or owned/licensed audio.
- If the clip relies on audio, still make the visual story understandable without
  sound.
- Add small transition hits only if they do not make the ad feel cheap or overly
  template-like.

### 11. Export Settings

Resolve Deliver page baseline:

```text
Format: MP4
Codec: H.264
Resolution: 1080 x 1920
Frame rate: same as timeline
Quality: Automatic Best, or restrict around 20,000-35,000 Kb/s
Audio: AAC, 48 kHz
Filename: filmtone_meta_9x16_15s_before-after_v001.mp4
```

If the upload looks soft after Meta processing, export a higher bitrate master
and let Meta compress from a cleaner source.

### 12. QC Checklist

Before calling an asset ready:

- First frame shows footage or transformation, not only a logo.
- Before/After difference is visible within 1-2 seconds.
- No black bars unless intentional.
- Text and logo are inside safe zones.
- Works with sound off.
- No copyrighted music if boosting.
- App name/identity appears by the end.
- Export is 1080 x 1920 9:16.
- File plays correctly on iPhone.
- Upload preview in Instagram/Facebook does not crop important content.
- Color does not look washed out or over-dark on iPhone after export.
- If using app UI screen recording, UI text is not too small to understand.

## Asset Questions The Next Chat Can Ask

Ask only for concrete production inputs, not broad marketing direction:

1. Which footage should be used for Before/After?
2. Are Before and After already exported from Filmtone, or should Resolve show a
   simulated comparison using app output?
3. Should the first deliverable be 15 seconds or 30 seconds?
4. Is the asset for Reels/Stories only, or also Feed?
5. Does the user want screen-recorded app UI in the ad, or only final footage?
6. What exact text should be placed in `COPY_01`, `COPY_02`, and `COPY_03`?
7. Is there cleared music/audio, or should the first version be silent?

## Best Next Step

The next chat should start by asking the user for the actual footage/source
assets and desired Resolve control mode.

Recommended first response shape in the next chat:

```text
了解です。コピーは扱わず、DaVinci上の作業に絞ります。
まず 9:16 / 15秒 の主力版を1本作り、その後30秒マスターへ広げるのがよさそうです。
Before素材、After素材、ロゴ/アイコン、入れたい文言だけください。
素材が揃ったら、Resolveでタイムライン作成、Before/After合わせ、ワイプ比較、書き出しまで順番に進めます。
```

If the user wants hands-on guidance, provide menu-level DaVinci instructions. If
the user wants the agent to operate the desktop app directly, use the available
desktop/computer control tools if the environment supports it.

## English Handoff Prompt For Maximum Accuracy

Use this prompt in a new chat:

```text
You are helping with Filmtone iOS growth work in the repository:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

First follow the repo rules in AGENTS.md. For iOS context, open
apps/capacitor-film-lab-ios/CLAUDE.md. Before stating any iOS public version,
local candidate version, App Store status, pricing, or release scope, run:
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Current task:
Support concrete DaVinci Resolve operations for creating Facebook/Instagram
Before/After ad assets for Filmtone iOS. The user rejected copywriting help and
will write all ad wording themselves. Do not propose Japanese ad copy unless the
user explicitly asks. Focus on Resolve workflow: project setup, bins, 9:16
timeline, import, Before/After alignment, vertical reframing, hard-cut reveal,
split-screen comparison, animated wipe reveal, safe-zone placeholder text,
cleared audio, export settings, and QC.

Important scope:
- Current active lane: Before/After material for Facebook/Instagram ads.
- Out of scope in this chat: App Store Custom Product Pages and Apple Ads/Search
  Ads setup; those are being handled in separate chats.
- User wants practical DaVinci operation support, not marketing theory.

Platform guidance already checked:
- Meta generally recommends video ads up to about 15 seconds.
- Reels/Stories primary format should be 9:16 vertical.
- Boosted Instagram Reels must be under 90 seconds and full-screen 9:16.
- Avoid copyrighted music if the Reel may be boosted.
- Keep key messages inside safe zones and make the video work without sound.

Recommended production plan:
1. Build one 1080x1920 9:16 15-second primary asset first.
2. Optionally build a 30-second 9:16 master after the 15-second version works.
3. Optionally cut a 6-second snap test.
4. Use user-provided text only; placeholders may be named COPY_01_HOOK,
   COPY_02_REVEAL, COPY_03_CTA.
5. Export H.264 MP4, 1080x1920, timeline frame rate, AAC audio, around
   20-35 Mbps or automatic best.

Ask the user for concrete assets only:
- Before footage
- After footage or Filmtone export
- app icon/logo if needed
- exact text they want placed on screen
- whether to include app UI screen recording
- whether audio is silent, licensed, or from a cleared source
- whether the first deliverable is 15s or 30s

When helping in DaVinci, give menu-level instructions and exact operations:
create bins, create a 1080x1920 timeline, place Before on V1 and After on V2,
align frames, crop/reframe, create split-screen or animated wipe, add safe-zone
text placeholders, export, and run QC. Keep the response practical and do not
return to copywriting unless asked.
```
