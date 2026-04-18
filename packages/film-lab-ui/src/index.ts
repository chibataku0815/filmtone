// UI contract (life#87 — shared mental model for Web + Desktop)
export {
  FILM_LAB_CONTROL_PANEL_SECTION_ORDER,
  FILM_LAB_MESSAGES_MANIFEST_PATH,
  FILM_LAB_NEXT_INTL_NAMESPACE,
  FILM_LAB_PRESET_PRIMARY_SURFACE_ID,
  FILM_LAB_WRAPPER_SLOT_IDS,
  type FilmLabControlPanelSectionId,
  type FilmLabWrapperSlotId,
} from "./filmLabUiContract";

/** パネル視覚トークン（Tailwind 束）。Web wrapper の見出し揃えにも使う。 */
export {
  filmLabCollapsibleHeaderButton,
  filmLabDonationPresentRowShell,
  filmLabModeToggleButtonBase,
  filmLabModeToggleButtonClassName,
  filmLabModeToggleGroupShell,
  filmLabModeToggleSegmentActive,
  filmLabModeToggleSegmentInactive,
  filmLabPanelRootClassName,
  filmLabPanelSurfaceBare,
  filmLabPanelSurfaceCard,
  filmLabPresetSectionDividerBlock,
  filmLabSectionHeaderTitle,
  filmLabToggleHeaderTitle,
  filmLabToggleHeaderTrackOff,
  filmLabToggleHeaderTrackOn,
} from "./filmLabPanelTokens";

export type { VideoPlaybackState } from "./videoPlaybackContract";
export {
  VideoTransportControls,
  type VideoTransportControlsProps,
} from "./VideoTransportControls";

// Components
export {
  FilmLabCanvas,
  type FilmLabCanvasRef,
  type FilmLabCanvasPreprocessResult,
  type FilmLabCanvasPreviewHealth,
  type FilmLabInteractiveSourceInfo,
  type ProgressiveTextureStage,
} from "./FilmLabCanvasPackageEntry";
export {
  FilmLabWebglPanelBackdrop,
  type FilmLabWebglPanelBackdropProps,
} from "./FilmLabWebglPanelBackdrop";
export {
  FilmLabControlPanelCore,
  type FilmLabControlPanelCoreSlots,
  type FilmLabCoreRef,
  type FilmLabCoreRenderContext,
  type FilmLabDonationUiBinding,
} from "./FilmLabControlPanelCore";
export { SectionHeader, type SectionHeaderProps } from "./ui/SectionHeader";
export { ToggleHeader, type ToggleHeaderProps } from "./ui/ToggleHeader";
export { LUTPanel } from "./LUTPanel";
export { PresetBar } from "./PresetBar";
export { PresetSearchSelect } from "./PresetSearchSelect";
export { FilmLabInfoTip, type FilmLabInfoTipProps } from "./FilmLabInfoTip";

// Source visibility contract (life#87 P3 docs + types)
export {
  FILM_LAB_SOURCE_DISPLAY_PRIORITY_ORDER,
  type FilmLabSourceDisplayBand,
} from "./filmLabSourceContract";

// UI primitives
export { ControlSlider } from "./ui/ControlSlider";
export { Histogram } from "./ui/Histogram";
export {
  MOBILE_PHASE0_QUICK_DEFAULTS,
  MOBILE_PHASE0_QUICK_KEYS,
  applyMobilePhase0QuickToParams,
  createMobilePhase0QuickPatch,
  setMobilePhase0QuickValue,
  type MobilePhase0QuickKey,
  type MobilePhase0QuickValues,
} from "./mobilePhase0Quick";

// State
export {
  filmLabReducer,
  createInitialState,
  createInitialStateFromSharedParams,
  toPresentSnapshot,
  type Action,
  type State,
  type PresentState,
  type GradeSlotState,
  type SlotId,
} from "./film-lab-reducer";
