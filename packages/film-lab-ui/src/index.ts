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
// Components
export {
  FilmLabCanvas,
  type FilmLabCanvasRef,
  type FilmLabInteractiveSourceInfo,
} from "./FilmLabCanvasPackageEntry";
export {
  FilmLabControlPanelCore,
  SectionHeader,
  ToggleHeader,
  type FilmLabControlPanelCoreSlots,
  type FilmLabCoreRenderContext,
  type FilmLabDonationUiBinding,
} from "./FilmLabControlPanelCore";
export { LUTPanel } from "./LUTPanel";
export { PresetBar } from "./PresetBar";
export { PresetSearchSelect } from "./PresetSearchSelect";
export { FilmLabInfoTip, type FilmLabInfoTipProps } from "./FilmLabInfoTip";

// UI primitives
export { ControlSlider } from "./ui/ControlSlider";
export { Histogram } from "./ui/Histogram";

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

// Quick mode
export {
  quickMetaPatchForValue,
  quickMetaDisplayValue,
  type QuickMetaAxis,
} from "./quick-meta-sliders";
