import { useMemo } from "react";
import { MobilePhase0Editor } from "@/features/editor/MobilePhase0Editor";
import { getAppStrings, resolveAppLocale } from "@/lib/messages";

export default function App() {
  const locale = resolveAppLocale();
  const strings = useMemo(() => getAppStrings(locale), [locale]);

  return (
    <main className="min-h-screen bg-[var(--app-bg)] text-[var(--text-base)]">
      <div className="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-6 sm:px-6">
        <header className="flex items-baseline justify-between px-1">
          <h1 className="text-base font-medium tracking-[-0.01em] text-white">
            {strings.appName}
          </h1>
        </header>

        <MobilePhase0Editor strings={strings} />
      </div>
    </main>
  );
}
