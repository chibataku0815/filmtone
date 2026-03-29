/**
 * Film Lab デスクトップ — 高速動画書き出しの internal acceptance matrix
 *
 * @overview fast 経路は public default に戻さない。再有効化前に最低限確認すべきケースだけをコード側で固定する。
 * 実サンプル資産は別途必要だが、確認対象そのものはここでブレないようにする。
 */

export type FastVideoExportAcceptanceCase = {
  id: string;
  label: string;
  description: string;
};

export const FAST_VIDEO_EXPORT_INTERNAL_ACCEPTANCE_CASES: readonly FastVideoExportAcceptanceCase[] =
  [
    {
      id: "preset-only",
      label: "Preset Only",
      description: "組み込みプリセットのみ。LUT なしで Params 近似の崩れを確認する。",
    },
    {
      id: "preview-sync-slider-only",
      label: "Preview Sync Slider Only",
      description: "編集タブから同期したスライダー数値のみ。gradeParams の受け渡し退行を確認する。",
    },
    {
      id: "imported-json-with-lut",
      label: "Imported JSON + LUT",
      description: "JSON 由来の .cube LUT を含むケース。LUT-first の公開前提を確認する。",
    },
    {
      id: "imported-json-without-lut",
      label: "Imported JSON Without LUT",
      description: "LUT なし JSON。schema validate 後に Params のみで処理されることを確認する。",
    },
    {
      id: "audio-present",
      label: "Audio Present",
      description: "音声あり動画。fast path の map/copy 契約と shortest 動作を確認する。",
    },
    {
      id: "audio-absent",
      label: "Audio Absent",
      description: "音声なし動画。-an 契約で正常終了することを確認する。",
    },
  ] as const;
