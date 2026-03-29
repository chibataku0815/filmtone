/**
 * Film Lab バッチ — レンダラ UI（最小）
 *
 * @overview フォルダ・JSON の選択と runBatchPipeline 呼び出しだけ行う。
 */
import { runBatchPipeline, type BatchFormat } from "./batch-pipeline";

const el = (id: string): HTMLElement => {
  const n = document.getElementById(id);
  if (!n) throw new Error(`main.ts: #${id} が見つかりません`);
  return n;
};

function logLine(line: string): void {
  const log = el("log");
  log.textContent = `${log.textContent ?? ""}${line}\n`;
  log.scrollTop = log.scrollHeight;
}

let inputDir: string | null = null;
let outputDir: string | null = null;
let gradePath: string | null = null;

function refreshRunEnabled(): void {
  const btn = el("btnRun") as HTMLButtonElement;
  btn.disabled = !(inputDir && outputDir && gradePath);
}

el("btnInput").addEventListener("click", async () => {
  const p = await window.filmLabBatch.pickInputDir();
  inputDir = p;
  el("inputLabel").textContent = p ?? "—";
  refreshRunEnabled();
});

el("btnOutput").addEventListener("click", async () => {
  const p = await window.filmLabBatch.pickOutputDir();
  outputDir = p;
  el("outputLabel").textContent = p ?? "—";
  refreshRunEnabled();
});

el("btnGrade").addEventListener("click", async () => {
  const p = await window.filmLabBatch.pickGradeJson();
  gradePath = p;
  el("gradeLabel").textContent = p ?? "—";
  refreshRunEnabled();
});

el("btnRun").addEventListener("click", async () => {
  if (!inputDir || !outputDir || !gradePath) return;

  const formatSel = el("formatSel") as HTMLSelectElement;
  const format = formatSel.value as BatchFormat;

  el("log").textContent = "";
  logLine(`Input: ${inputDir}`);
  logLine(`Output: ${outputDir}`);
  logLine(`Grade: ${gradePath}`);
  logLine(`Format: ${format}`);

  const btn = el("btnRun") as HTMLButtonElement;
  btn.disabled = true;

  try {
    const images = await window.filmLabBatch.listImages(inputDir);
    logLine(`Images: ${images.length}`);
    if (images.length === 0) {
      logLine("画像がありません（.jpg / .jpeg / .png）");
      return;
    }

    const gradeJsonText = await window.filmLabBatch.readFileUtf8(gradePath);

    await runBatchPipeline({
      api: window.filmLabBatch,
      gradeJsonPath: gradePath,
      gradeJsonText,
      imagePaths: images,
      outputDir,
      format,
      onLog: logLine,
    });

    logLine("Done.");
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    logLine(`FATAL: ${msg}`);
  } finally {
    btn.disabled = false;
    refreshRunEnabled();
  }
});

refreshRunEnabled();
