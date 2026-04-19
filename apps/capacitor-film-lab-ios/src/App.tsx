import { useMemo } from "react";
import {
  PHASE0_BENCHMARK_GATES,
  PHASE0_MAX_SOURCE_DURATION_SEC,
  PHASE0_OUTPUT_PROFILE,
} from "film-lab-core";
import { MobilePhase0Editor } from "@/features/editor/MobilePhase0Editor";
import { getAppStrings, resolveAppLocale } from "@/lib/messages";

export default function App() {
  const locale = resolveAppLocale();
  const strings = useMemo(() => getAppStrings(locale), [locale]);

  return (
    <main className="min-h-screen bg-[var(--app-bg)] text-[var(--text-base)]">
      <div className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-6 sm:px-6">
        <header className="rounded-[28px] border border-white/10 bg-white/[0.03] p-5 shadow-[0_24px_80px_rgba(0,0,0,0.35)]">
          <p className="text-[11px] uppercase tracking-[0.2em] text-[var(--text-muted)]">
            {strings.headerEyebrow}
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-[-0.03em] text-white">
            {strings.headerTitle}
          </h1>
          <p className="mt-3 max-w-2xl text-sm leading-6 text-[var(--text-base-70)]">
            {strings.headerBody}
          </p>
          <div className="mt-4 grid gap-3 rounded-2xl border border-white/8 bg-black/20 p-4 text-sm text-[var(--text-base-70)] sm:grid-cols-3">
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.fixedOutput}
              </div>
              <div className="mt-1 text-white">
                {PHASE0_OUTPUT_PROFILE.codec.toUpperCase()} / {PHASE0_OUTPUT_PROFILE.container.toUpperCase()} / {PHASE0_OUTPUT_PROFILE.fps}fps / 1080p
              </div>
            </div>
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.fixedCaps}
              </div>
              <div className="mt-1 text-white">
                {PHASE0_MAX_SOURCE_DURATION_SEC / 60} min max
              </div>
            </div>
            <div>
              <div className="text-[10px] uppercase tracking-[0.16em] text-[var(--text-muted)]">
                {strings.fixedGate}
              </div>
              <div className="mt-1 text-white">
                60s ≤ {PHASE0_BENCHMARK_GATES.passRealtimeRatio.toFixed(1)}x realtime
              </div>
            </div>
          </div>
        </header>

        <MobilePhase0Editor strings={strings} />
      </div>
    </main>
  );
}
