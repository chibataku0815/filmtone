// Components
export { FilmLabCanvas, type FilmLabCanvasRef } from "./FilmLabCanvasPackageEntry";
export {
  FilmLabControlPanelCore,
  SectionHeader,
  ToggleHeader,
  type FilmLabControlPanelCoreSlots,
  type FilmLabDonationUiBinding,
} from "./FilmLabControlPanelCore";
export { LUTPanel } from "./LUTPanel";
export { PresetBar } from "./PresetBar";
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
