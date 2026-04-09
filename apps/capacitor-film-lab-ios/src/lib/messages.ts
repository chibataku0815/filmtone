import enMessages from "../../../web/messages/en.json";
import jaMessages from "../../../web/messages/ja.json";

export type AppLocale = "en" | "ja";

type FilmLabMessages = {
  "film-lab": {
    controls: Record<string, string>;
    lutPanel: Record<string, string>;
  };
};

const filmLabEn = (enMessages as FilmLabMessages)["film-lab"];
const filmLabJa = (jaMessages as FilmLabMessages)["film-lab"];

const appCopy = {
  en: {
    headerEyebrow: "Filmtone iOS Phase 0",
    headerTitle: "Local-first export kill-test",
    headerBody:
      "Start from one clip, choose a preset, nudge the Quick axes, optionally load one creative LUT, then export, save, and share. Preview polish is intentionally secondary to export viability.",
    fixedOutput: "Output",
    fixedCaps: "Input cap",
    fixedGate: "Pass gate",
    sourceSectionTitle: "Source",
    sourceEmpty: "Pick one source clip to begin.",
    pickSource: "Pick source",
    repickSource: "Replace source",
    probePending: "Inspecting source…",
    quickSectionTitle: "Quick",
    quickHint:
      "Three axes keep the path narrow. The exported payload still uses validated reduced params under the hood.",
    quickFilmCharacter: "Film character",
    quickEra: "Era",
    quickDynamics: "Dynamics",
    quickFilmCharacterHint: "Tone, warmth, grain, and edge falloff.",
    quickEraHint: "Fade and age without reopening the full Pro surface.",
    quickDynamicsHint: "Exposure and contrast pressure.",
    lutSectionTitle: "Creative LUT",
    lutEmpty: "Optional. Parsed in TypeScript, passed to native as validated cube data.",
    pickLut: "Load .cube",
    clearLut: "Clear LUT",
    exportSectionTitle: "Export",
    exportIdle: "Ready to export on device.",
    exportRunning: "Export in progress…",
    exportWritingHint: "Finalizing output. Long clips can sit here briefly.",
    exportStart: "Run export",
    exportDisabled: "Source must be within Phase 0 caps before export starts.",
    saveToPhotos: "Save to Photos",
    saveToPhotosDone: "Saved to Photos.",
    shareOutput: "Share output",
    resultTitle: "Last result",
    benchmarkTitle: "Benchmark defaults",
    benchmarkBody:
      "Pass: 60s clip ≤ 2.5x realtime. Strong go: ≤ 2.0x realtime. iPad stays out of Phase 0 gating.",
    validationTargetTitle: "Current validation target",
    validationTargetBody:
      "Use one fixed exact 60-second segment trimmed from the known-good 4m29s source, with preset + creative LUT.",
    validationTargetFootnote:
      "This is the formal 60s gate. Keep the settings profile explicit in the report and inspect the exported file at the start, middle, and end.",
    reducedParamsTitle: "Reduced params",
    reducedParamsBody:
      "Exposure, contrast, saturation, temperature, tint, fade, vignette, optional grain.",
    sourceViolationsTitle: "Blocked by source caps",
    sourceAllowedTitle: "Within Phase 0 source caps",
    sourceInfoTitle: "Source status",
    previewTitle: "Preview",
    previewHint:
      "This preview is convenience-only. Exported files remain the product truth for Phase 0 decisions.",
    metricsElapsed: "Elapsed",
    metricsRealtime: "Realtime",
    metricsOutput: "Output",
    metricsFileSize: "File size",
    metricsThermal: "Thermal",
    metricsMemoryWarnings: "Memory warnings",
    metricsSaveToPhotos: "Save to Photos",
    validationReportTitle: "Validation capture",
    validationReportBody:
      "Paste this into chat after the run and replace the manual-check lines after reviewing the exported file.",
    errorPrefix: "Error",
    noticePrefix: "Note",
  },
  ja: {
    headerEyebrow: "Filmtone iOS Phase 0",
    headerTitle: "local-first export kill-test",
    headerBody:
      "1 本のクリップを起点に、プリセット、Quick 3 軸、任意の creative LUT を通し、export・保存・共有までを見るための最小導線です。プレビューの磨き込みはこの段階の主題ではありません。",
    fixedOutput: "出力条件",
    fixedCaps: "入力上限",
    fixedGate: "合格ライン",
    sourceSectionTitle: "ソース",
    sourceEmpty: "最初に 1 本の素材を選んでください。",
    pickSource: "素材を選ぶ",
    repickSource: "素材を差し替える",
    probePending: "素材を確認しています…",
    quickSectionTitle: "Quick",
    quickHint:
      "導線は 3 軸に絞ります。export payload 自体は reduced params として検証済みの形で native に渡します。",
    quickFilmCharacter: "フィルム調",
    quickEra: "新旧",
    quickDynamics: "ダイナミック",
    quickFilmCharacterHint: "色味、温度感、粒状感、周辺の落ちをまとめて触ります。",
    quickEraHint: "full Pro を開かずに褪せや経年感を足します。",
    quickDynamicsHint: "露出とコントラストの圧を動かします。",
    lutSectionTitle: "Creative LUT",
    lutEmpty: "任意です。.cube は TypeScript 側で parse し、検証済みデータだけを native に渡します。",
    pickLut: ".cube を読み込む",
    clearLut: "LUT を外す",
    exportSectionTitle: "書き出し",
    exportIdle: "端末上の export 準備はできています。",
    exportRunning: "書き出し中…",
    exportWritingHint: "出力の最終化中です。長尺クリップではここが少し長く見えることがあります。",
    exportStart: "書き出しを実行",
    exportDisabled: "Phase 0 の入力上限に収まった素材だけ export を開始します。",
    saveToPhotos: "写真へ保存",
    saveToPhotosDone: "写真への保存が完了しました。",
    shareOutput: "共有",
    resultTitle: "直近の結果",
    benchmarkTitle: "ベンチマーク既定",
    benchmarkBody:
      "Pass: 60 秒クリップが realtime の 2.5 倍以下。Strong go: 2.0 倍以下。iPad は Phase 0 gating の外です。",
    validationTargetTitle: "今回の検証ターゲット",
    validationTargetBody:
      "前回成功した 4 分 29 秒素材から切り出した固定 60 秒区間を、preset + creative LUT で検証します。",
    validationTargetFootnote:
      "これは正式な 60 秒 benchmark gate です。Settings profile を明記し、書き出しファイルの冒頭・中盤・終盤を確認してください。",
    reducedParamsTitle: "Reduced params",
    reducedParamsBody:
      "露出、コントラスト、彩度、色温度、ティント、フェード、ビネット、任意のグレイン。",
    sourceViolationsTitle: "入力上限を超えています",
    sourceAllowedTitle: "Phase 0 入力上限内です",
    sourceInfoTitle: "ソース状態",
    previewTitle: "プレビュー",
    previewHint:
      "このプレビューは確認用です。Phase 0 の判断基準として正にするのは export 後の実ファイルです。",
    metricsElapsed: "経過時間",
    metricsRealtime: "Realtime 比",
    metricsOutput: "出力",
    metricsFileSize: "ファイルサイズ",
    metricsThermal: "サーマル",
    metricsMemoryWarnings: "メモリ警告",
    metricsSaveToPhotos: "写真への保存",
    validationReportTitle: "検証記録",
    validationReportBody:
      "run 後にこの内容をチャットへ貼り、書き出しファイルを確認して manual-check の行だけ埋めてください。",
    errorPrefix: "エラー",
    noticePrefix: "補足",
  },
} as const;

export type AppStrings = ReturnType<typeof getAppStrings>;

export function resolveAppLocale(): AppLocale {
  if (typeof navigator !== "undefined" && navigator.language.toLowerCase().startsWith("ja")) {
    return "ja";
  }
  return "en";
}

export function getAppStrings(locale: AppLocale) {
  const filmLab = locale === "ja" ? filmLabJa : filmLabEn;
  const base = appCopy[locale];
  return {
    ...base,
    presetLabel: filmLab.controls.presets,
    presetSelectTriggerLabel: filmLab.controls.presetSelectTriggerLabel,
    presetSearchPlaceholder: filmLab.controls.presetSearchPlaceholder,
    presetSearchEmpty: filmLab.controls.presetSearchEmpty,
    sliderResetHint: filmLab.controls.sliderLabelReset,
    lutMixLabel: filmLab.lutPanel.creativeMix,
    lutMixDisabledHint: filmLab.lutPanel.creativeMixDisabledHint,
  };
}
