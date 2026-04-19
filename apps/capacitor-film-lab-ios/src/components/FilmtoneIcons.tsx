/**
 * @file Filmtone iOS icon set.
 * @description
 * Re-exports Phosphor Icons (regular weight, default) under legacy Filmtone
 * names so callsites stay stable while every glyph is a vetted,
 * production-grade icon instead of a hand-rolled SVG.
 */

export {
  ArrowsClockwise as ReplaceIcon,
  CaretDown as ChevronDownIcon,
  Check as CheckIcon,
  Eye as CompareIcon,
  Export as ExportIcon,
  FilmReel as AppMarkIcon,
  Palette as LibraryIcon,
  ShareNetwork as ShareIcon,
  Sliders as SlidersIcon,
  Sparkle as SparkIcon,
  X as CloseIcon,
} from "@phosphor-icons/react";
