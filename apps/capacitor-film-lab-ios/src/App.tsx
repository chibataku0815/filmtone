import { useMemo } from "react";
import { MobilePhase0Editor } from "@/features/editor/MobilePhase0Editor";
import { getAppStrings, resolveAppLocale } from "@/lib/messages";

export default function App() {
  const locale = resolveAppLocale();
  const strings = useMemo(() => getAppStrings(locale), [locale]);

  return (
    <main className="min-h-screen bg-[var(--app-bg)] text-[var(--text-base)]">
      <MobilePhase0Editor strings={strings} />
    </main>
  );
}
