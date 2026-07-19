"use client";

/**
 * @fileoverview `FilmLabControlPanelCore` の Finish Tools（旧 Artifacts）セクションです。
 *
 * @description
 * レンズフィルター（Optical Filter Profile）・Mist・Glow（Bloom/Halation）・Halo Prism・
 * Cross Filter・Texture・Lens（RGB Shift/Lens Softness）・Motion の各ファミリーをまとめた
 * 折りたたみブロックです。ロジック（reducer dispatch・saved-value 記憶等）は
 * `FilmLabControlPanelCore` 本体に残し、ここは props 経由で受け取った値/コールバックを
 * 描画するだけの純粋な表示コンポーネントです（hooks は呼びません）。
 */
import { type ReactNode } from "react";
import { useTranslations } from "next-intl";
import {
  FILMTONE_SOFT_FINISH_PATCH,
  OPTICAL_FILTER_PROFILES,
  PHASE0_RGB_SHIFT_MAX,
  halationHueToHex,
  type OpticalFilterProfile,
  type OpticalFilterProfileId,
  type Params,
} from "film-lab-core";
import { PanelControlSlider } from "./ui/PanelControlSlider";
import { ToggleHeader } from "./ui/ToggleHeader";
import { SegmentedControl } from "./ui/SegmentedControl";
import { CollapsibleHeader } from "./ui/CollapsibleHeader";
import type { FilmLabCoreRenderContext } from "./FilmLabControlPanelCore";

const RGB_SHIFT_UI_MAX = PHASE0_RGB_SHIFT_MAX;
const RGB_SHIFT_UI_STEP = 0.0001;

function getRgbShiftSliderMax(rgbShift: number): number {
  return Math.max(RGB_SHIFT_UI_MAX, rgbShift);
}

function formatRgbShiftValue(rgbShift: number): string {
  return `${Math.round((rgbShift / RGB_SHIFT_UI_MAX) * 100)}%`;
}

const CROSS_FILTER_MIN_SPACING_MIN = 1;
const CROSS_FILTER_MIN_SPACING_MAX = 10;

type FinishToolStarterState = {
  id: "subtle" | "signature";
  labelKey: "controls.finishToolsStarterSubtle" | "controls.finishToolsStarterSignature";
  patch: Partial<Params>;
};

const CROSS_STARTER_STATES: readonly FinishToolStarterState[] = [
  {
    id: "subtle",
    labelKey: "controls.finishToolsStarterSubtle",
    patch: {
      crossFilterStrength: 0.25,
      crossFilterSpikes: 4,
      crossFilterAngle: 0,
      crossFilterLength: 0.38,
      crossFilterThreshold: 0.92,
      crossFilterChromatic: 0.18,
      crossFilterSizeLimit: 0.12,
      crossFilterRandomness: 0.9,
      crossFilterHardMode: 1,
      crossFilterMinSpacing: 1,
    },
  },
  {
    id: "signature",
    labelKey: "controls.finishToolsStarterSignature",
    patch: {
      crossFilterStrength: 0.55,
      crossFilterSpikes: 6,
      crossFilterAngle: 15,
      crossFilterLength: 0.62,
      crossFilterThreshold: 0.92,
      crossFilterChromatic: 0.4,
      crossFilterSizeLimit: 0.24,
      crossFilterRandomness: 0.75,
      crossFilterHardMode: 1,
      crossFilterMinSpacing: 1,
    },
  },
] as const;

const GLOW_STARTER_STATES: readonly FinishToolStarterState[] = [
  {
    id: "subtle",
    labelKey: "controls.finishToolsStarterSubtle",
    patch: FILMTONE_SOFT_FINISH_PATCH,
  },
  {
    id: "signature",
    labelKey: "controls.finishToolsStarterSignature",
    patch: {
      bloomStrength: 0.42,
      bloomThreshold: 0.64,
      bloomRadius: 0.62,
      diffusion: 0.16,
      halationIntensity: 0.22,
      halationSpread: 30,
      halationRadius: 0.60,
      halationHue: 26,
    },
  },
] as const;

const HALO_PRISM_STARTER_STATES: readonly FinishToolStarterState[] = [
  {
    id: "subtle",
    labelKey: "controls.finishToolsStarterSubtle",
    patch: {
      haloPrismStrength: 0.28,
      haloPrismRadius: 0.58,
      haloPrismWidth: 0.18,
      haloPrismChromatic: 0.55,
      haloPrismThreshold: 0.92,
      haloPrismSplit: 0.62,
      haloPrismAngle: 0,
      haloPrismSourceReactivity: 0.75,
    },
  },
  {
    id: "signature",
    labelKey: "controls.finishToolsStarterSignature",
    patch: {
      haloPrismStrength: 0.62,
      haloPrismRadius: 0.66,
      haloPrismWidth: 0.28,
      haloPrismChromatic: 0.85,
      haloPrismThreshold: 0.88,
      haloPrismSplit: 0.78,
      haloPrismAngle: 0,
      haloPrismSourceReactivity: 0.95,
    },
  },
] as const;

const HALO_PRISM_CONTROLS_VISIBLE = false;

const OPTICAL_FILTER_FAMILY_ORDER = [
  "blackMist",
  "cineBloom",
  "warmMist",
  "backlightVeil",
  "pearlGlow",
  "cleanSoft",
] as const satisfies readonly OpticalFilterProfile["family"][];

const OPTICAL_FILTER_FAMILY_LABELS = {
  blackMist: "Black Mist",
  cineBloom: "Cine Bloom",
  warmMist: "Warm Mist",
  backlightVeil: "Backlight Veil",
  pearlGlow: "Pearl Glow",
  cleanSoft: "Clean Soft",
} as const satisfies Partial<Record<OpticalFilterProfile["family"], string>>;

function FinishToolFamilyCard({
  title,
  first = false,
  headerAccessory,
  children,
}: {
  title: string;
  first?: boolean;
  headerAccessory?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className={first ? "" : "border-t border-white/[0.08] pt-4"}>
      <div className="mb-2 flex items-center justify-between gap-3">
        <h3 className="text-[11px] font-semibold uppercase tracking-[0.18em] text-white/82">
          {title}
        </h3>
        {headerAccessory ? (
          <div className="shrink-0">
            {headerAccessory}
          </div>
        ) : null}
      </div>

      <div>
        {children}
      </div>
    </section>
  );
}

function formatOpticalFilterDensityLabel(profile: OpticalFilterProfile): string {
  return profile.density === "subtle" ? "Subtle" : profile.shortLabel;
}

function OpticalFilterProfileGrid({
  profiles,
  selectedProfileId,
  onApply,
  tFilmLab,
}: {
  profiles: readonly OpticalFilterProfile[];
  selectedProfileId: OpticalFilterProfileId | null;
  onApply: (profile: OpticalFilterProfile) => void;
  tFilmLab: ReturnType<typeof useTranslations>;
}) {
  const groups = OPTICAL_FILTER_FAMILY_ORDER.map((family) => ({
    family,
    label: OPTICAL_FILTER_FAMILY_LABELS[family],
    profiles: profiles.filter((profile) => profile.family === family),
  })).filter((group) => group.profiles.length > 0);

  return (
    <div className="flex flex-col gap-2">
      <div className="overflow-hidden rounded-lg border border-white/[0.08] bg-black/[0.08]">
        {groups.map((group, index) => (
          <div
            key={group.family}
            className={[
              "grid grid-cols-[92px_minmax(0,1fr)] items-center gap-2 px-2 py-1.5",
              index > 0 ? "border-t border-white/[0.06]" : "",
            ].join(" ")}
          >
            <div className="min-w-0">
              <div className="truncate text-[10px] font-semibold leading-none text-white/74">
                {group.label}
              </div>
            </div>
            <div className="flex min-w-0 flex-wrap justify-end gap-1.5">
              {group.profiles.map((profile) => {
                const active = profile.id === selectedProfileId;
                return (
                  <button
                    key={profile.id}
                    type="button"
                    aria-label={`Apply ${profile.displayName}`}
                    aria-pressed={active}
                    onClick={() => onApply(profile)}
                    className={[
                      "h-7 min-w-12 rounded-md border px-2 text-center text-[10px] font-semibold leading-none transition-colors",
                      active
                        ? "border-[var(--accent-amber1)]/70 bg-[var(--accent-amber1)]/16 text-[var(--accent-amber1)] shadow-[0_0_0_1px_rgba(255,200,69,0.18)]"
                        : "border-white/[0.09] bg-white/[0.03] text-white/68 hover:border-white/[0.16] hover:bg-white/[0.06] hover:text-white/88",
                    ].join(" ")}
                  >
                    {formatOpticalFilterDensityLabel(profile)}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>
      <p className="text-[9px] leading-snug text-white/36">
        {tFilmLab("controls.lensFilterDisclaimer")}
      </p>
    </div>
  );
}

function StarterStateButtonRow({
  states,
  params,
  onApply,
  tFilmLab,
}: {
  states: readonly FinishToolStarterState[];
  params: Params;
  onApply: (patch: Partial<Params>) => void;
  tFilmLab: ReturnType<typeof useTranslations>;
}) {
  return (
    <div className="flex flex-wrap justify-end gap-2">
        {states.map((state) => {
          const active = (Object.keys(state.patch) as Array<keyof Params>).every(
            (key) => params[key] === state.patch[key],
          );
          return (
            <button
              key={state.id}
              type="button"
              onClick={() => onApply(state.patch)}
              className={[
                "rounded-full border px-2.5 py-1 text-[10px] font-medium tracking-[0.08em] transition-colors",
                active
                  ? "border-[var(--accent-amber1)]/45 bg-[var(--accent-amber1)]/12 text-[var(--accent-amber1)]"
                  : "border-white/[0.1] bg-white/[0.03] text-white/72 hover:bg-white/[0.06] hover:text-white/88",
              ].join(" ")}
            >
              {tFilmLab(state.labelKey)}
            </button>
          );
        })}
    </div>
  );
}

function HueSlider({
  label,
  value,
  onChange,
  onCommit,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  onCommit?: () => void;
}) {
  const hex = halationHueToHex(value);
  return (
    <div className="flex min-h-[44px] min-w-0 items-center gap-3 sm:min-h-0 lg:pr-4">
      <span className="w-16 shrink-0 text-[11px] text-white/50 sm:w-24">{label}</span>
      <div className="relative min-w-0 flex-1">
        <input
          type="range"
          min={0}
          max={100}
          step={1}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          onPointerUp={() => onCommit?.()}
          onTouchEnd={() => onCommit?.()}
          className="halation-hue-slider h-1.5 min-w-0 w-full cursor-pointer appearance-none rounded-full touch-none sm:h-1"
          style={{
            background: `linear-gradient(to right, #e81020, #d83818, #c86010)`,
          }}
        />
      </div>
      <div
        className="h-4 w-4 shrink-0 rounded-full border border-white/20"
        style={{ backgroundColor: hex }}
      />
    </div>
  );
}

export interface FinishToolsSectionProps {
  tFilmLab: ReturnType<typeof useTranslations>;
  renderBeforeFinishTools?: (ctx: FilmLabCoreRenderContext) => ReactNode;
  beforeFinishTools?: ReactNode;
  coreRenderContext: FilmLabCoreRenderContext;
  artifactsOpen: boolean;
  onToggleArtifactsOpen: () => void;
  sliderLabelResetHint: string;
  params: Params;
  updateParam: (key: keyof Params, value: number) => void;
  commit: () => void;
  selectedOpticalFilterProfileId: OpticalFilterProfileId | null;
  applyOpticalFilterProfile: (profile: OpticalFilterProfile) => void;
  applyGlowStarterState: (patch: Partial<Params>) => void;
  bloomEnabled: boolean;
  toggleBloom: (on: boolean) => void;
  glowAdvancedOpen: boolean;
  onToggleGlowAdvancedOpen: () => void;
  halationEnabled: boolean;
  toggleHalation: (on: boolean) => void;
  updateHalationHue: (hue: number) => void;
  applyHaloPrismStarterState: (patch: Partial<Params>) => void;
  haloPrismEnabled: boolean;
  toggleHaloPrism: (on: boolean) => void;
  haloPrismAdvancedOpen: boolean;
  onToggleHaloPrismAdvancedOpen: () => void;
  applyCrossStarterState: (patch: Partial<Params>) => void;
  crossFilterEnabled: boolean;
  toggleCrossFilter: (on: boolean) => void;
  rgbShiftEnabled: boolean;
  toggleRgbShift: (on: boolean) => void;
}

/**
 * @description Finish Tools（レンズフィルター〜Motion まで）折りたたみブロック。
 * `FilmLabControlPanelCore` の `{isPro && (...)}` gate の内側に置く前提で、
 * このコンポーネント自体は `isPro` を見ません（呼び出し側が条件分岐を保持します）。
 */
export function FinishToolsSection({
  tFilmLab,
  renderBeforeFinishTools,
  beforeFinishTools,
  coreRenderContext,
  artifactsOpen,
  onToggleArtifactsOpen,
  sliderLabelResetHint,
  params,
  updateParam,
  commit,
  selectedOpticalFilterProfileId,
  applyOpticalFilterProfile,
  applyGlowStarterState,
  bloomEnabled,
  toggleBloom,
  glowAdvancedOpen,
  onToggleGlowAdvancedOpen,
  halationEnabled,
  toggleHalation,
  updateHalationHue,
  applyHaloPrismStarterState,
  haloPrismEnabled,
  toggleHaloPrism,
  haloPrismAdvancedOpen,
  onToggleHaloPrismAdvancedOpen,
  applyCrossStarterState,
  crossFilterEnabled,
  toggleCrossFilter,
  rgbShiftEnabled,
  toggleRgbShift,
}: FinishToolsSectionProps) {
  return (
    <div className="min-w-0">
      {renderBeforeFinishTools
        ? renderBeforeFinishTools(coreRenderContext)
        : beforeFinishTools}
      <CollapsibleHeader
        title={tFilmLab("controls.finishTools")}
        titleHint={tFilmLab("controls.finishToolsSectionHint")}
        open={artifactsOpen}
        onToggle={onToggleArtifactsOpen}
      />
      {artifactsOpen && (
        <div className="mt-2 flex flex-col gap-3">
          {tFilmLab("controls.finishToolsSectionHint") ? (
            <p className="text-[10px] leading-snug text-white/50">
              {tFilmLab("controls.finishToolsSectionHint")}
            </p>
          ) : null}

          <FinishToolFamilyCard
            first
            title={tFilmLab("controls.lensFilter")}
          >
            <OpticalFilterProfileGrid
              profiles={OPTICAL_FILTER_PROFILES}
              selectedProfileId={selectedOpticalFilterProfileId}
              onApply={applyOpticalFilterProfile}
              tFilmLab={tFilmLab}
            />
          </FinishToolFamilyCard>

          <FinishToolFamilyCard
            title={tFilmLab("controls.finishToolsMist")}
          >
            <PanelControlSlider
              sliderLabelResetHint={sliderLabelResetHint}
              label={tFilmLab("controls.diffusion")}
              value={params.diffusion}
              min={0}
              max={1}
              step={0.01}
              defaultValue={0}
              onChange={(v) => updateParam("diffusion", v)}
              onCommit={commit}
            />
          </FinishToolFamilyCard>

          <FinishToolFamilyCard
            title={tFilmLab("controls.finishToolsGlow")}
            headerAccessory={(
              <StarterStateButtonRow
                states={GLOW_STARTER_STATES}
                params={params}
                onApply={applyGlowStarterState}
                tFilmLab={tFilmLab}
              />
            )}
          >
            <ToggleHeader
              title={tFilmLab("controls.bloom")}
              titleHint={tFilmLab("controls.bloomToggleHint")}
              enabled={bloomEnabled}
              onToggle={toggleBloom}
            />
            <div className={`flex flex-col gap-2.5 ${!bloomEnabled ? "pointer-events-none opacity-30" : ""}`}>
              <PanelControlSlider
                sliderLabelResetHint={sliderLabelResetHint}
                label={tFilmLab("controls.strength")}
                value={params.bloomStrength}
                min={0}
                max={3}
                step={0.01}
                defaultValue={0}
                onChange={(v) => updateParam("bloomStrength", v)}
                onCommit={commit}
              />
            </div>
            <button
              type="button"
              onClick={onToggleGlowAdvancedOpen}
              className="mt-3 rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2 text-[10px] font-medium tracking-[0.08em] text-white/68 transition-colors hover:bg-white/[0.06] hover:text-white/84"
            >
              {glowAdvancedOpen
                ? tFilmLab("controls.finishToolsAdvancedHide")
                : tFilmLab("controls.finishToolsAdvancedShow")}
            </button>

            {glowAdvancedOpen ? (
              <div className="mt-3 flex flex-col gap-2.5 border-t border-white/[0.08] pt-3">
                <div className={`flex flex-col gap-2.5 ${!bloomEnabled ? "pointer-events-none opacity-30" : ""}`}>
                  <PanelControlSlider
                    sliderLabelResetHint={sliderLabelResetHint}
                    label={tFilmLab("controls.threshold")}
                    hint={tFilmLab("controls.bloomThresholdHint")}
                    value={params.bloomThreshold}
                    min={0}
                    max={1}
                    step={0.01}
                    defaultValue={0.8}
                    onChange={(v) => updateParam("bloomThreshold", v)}
                    onCommit={commit}
                  />
                  <PanelControlSlider
                    sliderLabelResetHint={sliderLabelResetHint}
                    label={tFilmLab("controls.radius")}
                    value={params.bloomRadius}
                    min={0}
                    max={1}
                    step={0.01}
                    defaultValue={0.4}
                    onChange={(v) => updateParam("bloomRadius", v)}
                    onCommit={commit}
                  />
                </div>

                <ToggleHeader
                  title={tFilmLab("controls.halation")}
                  titleHint={tFilmLab("controls.halationToggleHint")}
                  enabled={halationEnabled}
                  onToggle={toggleHalation}
                />
                <div className={`flex flex-col gap-2.5 ${!halationEnabled ? "pointer-events-none opacity-30" : ""}`}>
                  <PanelControlSlider
                    sliderLabelResetHint={sliderLabelResetHint}
                    label={tFilmLab("controls.intensity")}
                    value={params.halationIntensity}
                    min={0}
                    max={1}
                    step={0.01}
                    defaultValue={0}
                    onChange={(v) => updateParam("halationIntensity", v)}
                    onCommit={commit}
                  />
                  <PanelControlSlider
                    sliderLabelResetHint={sliderLabelResetHint}
                    label={tFilmLab("controls.spread")}
                    value={params.halationSpread}
                    min={0}
                    max={50}
                    step={0.5}
                    defaultValue={15}
                    onChange={(v) => updateParam("halationSpread", v)}
                    onCommit={commit}
                  />
                  <HueSlider
                    label={tFilmLab("controls.halationHue")}
                    value={params.halationHue}
                    onChange={updateHalationHue}
                    onCommit={commit}
                  />
                </div>
              </div>
            ) : null}
          </FinishToolFamilyCard>

          {HALO_PRISM_CONTROLS_VISIBLE ? (
            <FinishToolFamilyCard
              title={tFilmLab("controls.finishToolsHaloPrism")}
              headerAccessory={(
                <StarterStateButtonRow
                  states={HALO_PRISM_STARTER_STATES}
                  params={params}
                  onApply={applyHaloPrismStarterState}
                  tFilmLab={tFilmLab}
                />
              )}
            >
              <ToggleHeader
                title={tFilmLab("controls.haloPrism")}
                titleHint={tFilmLab("controls.haloPrismToggleHint")}
                enabled={haloPrismEnabled}
                onToggle={toggleHaloPrism}
              />
              <div className={`flex flex-col gap-2.5 ${!haloPrismEnabled ? "pointer-events-none opacity-30" : ""}`}>
                <PanelControlSlider
                  sliderLabelResetHint={sliderLabelResetHint}
                  label={tFilmLab("controls.strength")}
                  value={params.haloPrismStrength}
                  min={0}
                  max={1}
                  step={0.01}
                  defaultValue={0}
                  onChange={(v) => updateParam("haloPrismStrength", v)}
                  onCommit={commit}
                />
                <PanelControlSlider
                  sliderLabelResetHint={sliderLabelResetHint}
                  label={tFilmLab("controls.radius")}
                  hint={tFilmLab("controls.haloPrismRadiusHint")}
                  value={params.haloPrismRadius}
                  min={0}
                  max={1}
                  step={0.01}
                  defaultValue={0.62}
                  onChange={(v) => updateParam("haloPrismRadius", v)}
                  onCommit={commit}
                />
                <PanelControlSlider
                  sliderLabelResetHint={sliderLabelResetHint}
                  label={tFilmLab("controls.haloPrismWidth")}
                  hint={tFilmLab("controls.haloPrismWidthHint")}
                  value={params.haloPrismWidth}
                  min={0}
                  max={1}
                  step={0.01}
                  defaultValue={0.22}
                  onChange={(v) => updateParam("haloPrismWidth", v)}
                  onCommit={commit}
                />
                <PanelControlSlider
                  sliderLabelResetHint={sliderLabelResetHint}
                  label={tFilmLab("controls.haloPrismChromatic")}
                  hint={tFilmLab("controls.haloPrismChromaticHint")}
                  value={params.haloPrismChromatic}
                  min={0}
                  max={1}
                  step={0.01}
                  defaultValue={0.65}
                  onChange={(v) => updateParam("haloPrismChromatic", v)}
                  onCommit={commit}
                />
                <PanelControlSlider
                  sliderLabelResetHint={sliderLabelResetHint}
                  label={tFilmLab("controls.threshold")}
                  hint={tFilmLab("controls.haloPrismThresholdHint")}
                  value={params.haloPrismThreshold}
                  min={0}
                  max={1}
                  step={0.01}
                  defaultValue={0.9}
                  onChange={(v) => updateParam("haloPrismThreshold", v)}
                  onCommit={commit}
                />
              </div>
              <button
                type="button"
                onClick={onToggleHaloPrismAdvancedOpen}
                className="mt-3 rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2 text-[10px] font-medium tracking-[0.08em] text-white/68 transition-colors hover:bg-white/[0.06] hover:text-white/84"
              >
                {haloPrismAdvancedOpen
                  ? tFilmLab("controls.finishToolsAdvancedHide")
                  : tFilmLab("controls.finishToolsAdvancedShow")}
              </button>

              {haloPrismAdvancedOpen ? (
                <div className={`mt-3 flex flex-col gap-2.5 border-t border-white/[0.08] pt-3 ${!haloPrismEnabled ? "pointer-events-none opacity-30" : ""}`}>
                  <PanelControlSlider
                    sliderLabelResetHint={sliderLabelResetHint}
                    label={tFilmLab("controls.haloPrismSplit")}
                    hint={tFilmLab("controls.haloPrismSplitHint")}
                    value={params.haloPrismSplit}
                    min={0}
                    max={1}
                    step={0.01}
                    defaultValue={0.7}
                    onChange={(v) => updateParam("haloPrismSplit", v)}
                    onCommit={commit}
                  />
                  <PanelControlSlider
                    sliderLabelResetHint={sliderLabelResetHint}
                    label={tFilmLab("controls.haloPrismAngle")}
                    hint={tFilmLab("controls.haloPrismAngleHint")}
                    value={params.haloPrismAngle}
                    min={0}
                    max={360}
                    step={1}
                    defaultValue={0}
                    onChange={(v) => updateParam("haloPrismAngle", v)}
                    onCommit={commit}
                    formatValue={(v) => `${Math.round(v)}°`}
                  />
                  <PanelControlSlider
                    sliderLabelResetHint={sliderLabelResetHint}
                    label={tFilmLab("controls.haloPrismSourceReactivity")}
                    hint={tFilmLab("controls.haloPrismSourceReactivityHint")}
                    value={params.haloPrismSourceReactivity}
                    min={0}
                    max={1}
                    step={0.01}
                    defaultValue={0.85}
                    onChange={(v) => updateParam("haloPrismSourceReactivity", v)}
                    onCommit={commit}
                  />
                </div>
              ) : null}
            </FinishToolFamilyCard>
          ) : null}

          <FinishToolFamilyCard
            title={tFilmLab("controls.finishToolsCross")}
            headerAccessory={(
              <StarterStateButtonRow
                states={CROSS_STARTER_STATES}
                params={params}
                onApply={applyCrossStarterState}
                tFilmLab={tFilmLab}
              />
            )}
          >
            <ToggleHeader
              title={tFilmLab("controls.crossFilter")}
              titleHint={tFilmLab("controls.crossFilterToggleHint")}
              enabled={crossFilterEnabled}
              onToggle={toggleCrossFilter}
            />
            <div className={`flex flex-col gap-2.5 ${!crossFilterEnabled ? "pointer-events-none opacity-30" : ""}`}>
              <PanelControlSlider
                sliderLabelResetHint={sliderLabelResetHint}
                label={tFilmLab("controls.crossFilterStrengthLabel")}
                value={params.crossFilterStrength}
                min={0}
                max={1}
                step={0.01}
                defaultValue={0}
                onChange={(v) => updateParam("crossFilterStrength", v)}
                onCommit={commit}
              />
              <div className="flex min-w-0 items-start gap-3 lg:pr-4">
                <div className="w-[7.5rem] shrink-0 text-[11px] leading-tight text-[var(--text-muted)] sm:w-[8.5rem]">
                  <div>{tFilmLab("controls.crossFilterSpikes")}</div>
                  <div className="mt-1 break-words whitespace-normal text-[10px] leading-snug text-white/42">
                    {tFilmLab("controls.crossFilterSpikesHint")}
                  </div>
                </div>
                <div className="flex min-w-0 flex-1 justify-end">
                  <SegmentedControl<"4" | "6" | "8">
                    options={[
                      { value: "4", label: "4" },
                      { value: "6", label: "6" },
                      { value: "8", label: "8" },
                    ]}
                    value={String(params.crossFilterSpikes) as "4" | "6" | "8"}
                    onChange={(value) => {
                      updateParam("crossFilterSpikes", Number(value));
                      commit();
                    }}
                    ariaLabel={tFilmLab("controls.crossFilterSpikes")}
                  />
                </div>
              </div>
              <PanelControlSlider
                sliderLabelResetHint={sliderLabelResetHint}
                label={tFilmLab("controls.crossFilterAngle")}
                hint={tFilmLab("controls.crossFilterAngleHint")}
                value={params.crossFilterAngle}
                min={0}
                max={360}
                step={1}
                defaultValue={0}
                onChange={(v) => updateParam("crossFilterAngle", v)}
                onCommit={commit}
                formatValue={(v) => `${Math.round(v)}°`}
              />
              <PanelControlSlider
                sliderLabelResetHint={sliderLabelResetHint}
                label={tFilmLab("controls.crossFilterLength")}
                hint={tFilmLab("controls.crossFilterLengthHint")}
                value={params.crossFilterLength}
                min={0}
                max={1}
                step={0.01}
                defaultValue={0.5}
                onChange={(v) => updateParam("crossFilterLength", v)}
                onCommit={commit}
              />
            </div>

            <div className={`mt-3 flex flex-col gap-2.5 border-t border-white/[0.08] pt-3 ${!crossFilterEnabled ? "pointer-events-none opacity-30" : ""}`}>
              <PanelControlSlider
                sliderLabelResetHint={sliderLabelResetHint}
                label={tFilmLab("controls.crossFilterThreshold")}
                hint={tFilmLab("controls.crossFilterThresholdHint")}
                value={params.crossFilterThreshold}
                min={0}
                max={1}
                step={0.01}
                defaultValue={0.92}
                onChange={(v) => updateParam("crossFilterThreshold", v)}
                onCommit={commit}
              />
              <PanelControlSlider
                sliderLabelResetHint={sliderLabelResetHint}
                label={tFilmLab("controls.crossFilterChromatic")}
                hint={tFilmLab("controls.crossFilterChromaticHint")}
                value={params.crossFilterChromatic}
                min={0}
                max={1}
                step={0.01}
                defaultValue={0.3}
                onChange={(v) => updateParam("crossFilterChromatic", v)}
                onCommit={commit}
              />
              <PanelControlSlider
                sliderLabelResetHint={sliderLabelResetHint}
                label={tFilmLab("controls.crossFilterMinSpacing")}
                hint={tFilmLab("controls.crossFilterMinSpacingHint")}
                value={params.crossFilterMinSpacing}
                min={CROSS_FILTER_MIN_SPACING_MIN}
                max={CROSS_FILTER_MIN_SPACING_MAX}
                step={0.01}
                defaultValue={CROSS_FILTER_MIN_SPACING_MIN}
                onChange={(v) => updateParam("crossFilterMinSpacing", v)}
                onCommit={commit}
                formatValue={(v) => v.toFixed(2)}
              />
            </div>
          </FinishToolFamilyCard>

          <FinishToolFamilyCard
            title={tFilmLab("controls.finishToolsTexture")}
          >
            <PanelControlSlider
              sliderLabelResetHint={sliderLabelResetHint}
              label={tFilmLab("controls.filmGrain")}
              value={params.grainIntensity}
              min={0}
              max={0.1}
              step={0.01}
              defaultValue={0}
              onChange={(v) => updateParam("grainIntensity", v)}
              onCommit={commit}
            />
            <PanelControlSlider
              sliderLabelResetHint={sliderLabelResetHint}
              label={tFilmLab("controls.grainSize")}
              value={params.grainSize}
              min={0}
              max={1}
              step={0.01}
              defaultValue={0.3}
              onChange={(v) => updateParam("grainSize", v)}
              onCommit={commit}
            />
            <PanelControlSlider
              sliderLabelResetHint={sliderLabelResetHint}
              label={tFilmLab("controls.vignette")}
              value={params.vignette}
              min={0}
              max={1}
              step={0.01}
              defaultValue={0}
              onChange={(v) => updateParam("vignette", v)}
              onCommit={commit}
            />
            <PanelControlSlider
              sliderLabelResetHint={sliderLabelResetHint}
              label={tFilmLab("controls.grainRadialMix")}
              hint={tFilmLab("controls.grainRadialMixHint")}
              value={params.grainRadialMix}
              min={0}
              max={1}
              step={0.01}
              defaultValue={1}
              onChange={(v) => updateParam("grainRadialMix", v)}
              onCommit={commit}
            />
          </FinishToolFamilyCard>

          <FinishToolFamilyCard
            title={tFilmLab("controls.finishToolsLens")}
          >
            <ToggleHeader
              title={tFilmLab("controls.rgbShift")}
              titleHint={tFilmLab("controls.rgbShiftToggleHint")}
              enabled={rgbShiftEnabled}
              onToggle={toggleRgbShift}
            />
            <div className={`flex flex-col gap-2.5 ${!rgbShiftEnabled ? "pointer-events-none opacity-30" : ""}`}>
              <PanelControlSlider
                sliderLabelResetHint={sliderLabelResetHint}
                label={tFilmLab("controls.strength")}
                hint={tFilmLab("effects.rgbShiftHint")}
                value={params.rgbShift}
                min={0}
                max={getRgbShiftSliderMax(params.rgbShift)}
                step={RGB_SHIFT_UI_STEP}
                defaultValue={0}
                formatValue={formatRgbShiftValue}
                onChange={(v) => updateParam("rgbShift", v)}
                onCommit={commit}
              />
            </div>
            <PanelControlSlider
              sliderLabelResetHint={sliderLabelResetHint}
              label={tFilmLab("controls.lensSoftness")}
              hint={tFilmLab("effects.lensSoftnessHint")}
              value={params.lensSoftness}
              min={0}
              max={1}
              step={0.01}
              defaultValue={0}
              formatValue={(v) => `${Math.round(v * 100)}%`}
              onChange={(v) => updateParam("lensSoftness", v)}
              onCommit={commit}
            />
          </FinishToolFamilyCard>

          <FinishToolFamilyCard
            title={tFilmLab("controls.finishToolsMotion")}
          >
            <PanelControlSlider
              sliderLabelResetHint={sliderLabelResetHint}
              label={tFilmLab("controls.shutterAngle")}
              hint={tFilmLab("controls.shutterAngleHint")}
              value={params.shutterAngle}
              min={0}
              max={720}
              step={10}
              defaultValue={0}
              onChange={(v) => updateParam("shutterAngle", v < 90 ? 0 : Math.max(180, v))}
              onCommit={commit}
            />
            <PanelControlSlider
              sliderLabelResetHint={sliderLabelResetHint}
              label={tFilmLab("controls.trailIntensity")}
              hint={tFilmLab("controls.trailIntensityHint")}
              value={params.trailIntensity}
              min={0}
              max={0.95}
              step={0.05}
              defaultValue={0}
              onChange={(v) => updateParam("trailIntensity", v)}
              onCommit={commit}
            />
          </FinishToolFamilyCard>
        </div>
      )}
    </div>
  );
}
