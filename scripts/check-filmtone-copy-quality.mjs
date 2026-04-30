#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const repoRoot = process.cwd();

const webMessagePaths = [
  "apps/web/messages/ja.json",
  "apps/web/messages/en.json",
];

const metadataFields = [
  "name",
  "subtitle",
  "promotional_text",
  "description",
  "keywords",
];

const metadataLocales = ["ja", "en-US"];

const appStoreLimits = new Map([
  ["name", { max: 30, metric: "chars" }],
  ["subtitle", { max: 30, metric: "chars" }],
  ["promotional_text", { max: 170, metric: "chars" }],
  ["description", { max: 4000, metric: "chars" }],
  ["keywords", { max: 100, metric: "bytes" }],
]);

const styleSkipKeyParts = [
  "aria",
  "label",
  "cta",
  "subline",
  "operatingsystem",
  "browserrequirements",
  "name",
  "eyebrow",
];

const highImpactKeyParts = [
  "title",
  "subtitle",
  "description",
  "promo",
  "promotional",
  "hero",
  "lead",
  "body",
  "og",
];

const roleWords = [
  "試す",
  "保存",
  "共有",
  "書き出",
  "確認",
  "再生",
  "選ぶ",
  "決め",
  "調整",
  "仕上げ",
  "try",
  "save",
  "share",
  "export",
  "check",
  "playback",
  "choose",
  "tune",
  "adjust",
  "finish",
  "judge",
];

const featureWords = [
  "プリセット",
  "Quick",
  "Before",
  "After",
  "比較",
  "LUT",
  "HDR",
  "Log",
  "P3",
  "ProRes",
  "書き出し",
  "保存",
  "共有",
  "presets",
  "controls",
  "compare",
  "LUTs",
  "export",
  "save",
  "share",
  "HDR",
  "Log",
  "P3",
  "ProRes",
];

const actionWords = [
  ...roleWords,
  "開く",
  "進め",
  "整え",
  "使う",
  "揃え",
  "open",
  "move",
  "shape",
  "keep",
  "use",
  "decide",
];

const rules = [
  {
    id: "forbidden-claim",
    appliesToKeywords: true,
    reason: "Unshipped or unverified claim is forbidden in public copy.",
    rewrite: "Remove the claim until the feature is shipped and separately verified.",
    patterns: [
      /\.cube\s+export/i,
      /combined\s+LUT\s+export/i,
      /public\s+sidecar\s+schema/i,
      /\bDaVinci\b/i,
      /ProRes\s*422/i,
      /full\s+Web\s+production\s+export/i,
      /dependable\s+full\s+Web\s+video\s+export/i,
      /奥行きを読む/,
      /光のにじみを物理で返す/,
      /フィルム光学エンジン/,
      /reads\s+scene\s+depth/i,
      /depth-aware\s+optics/i,
      /where\s+halation\s+belongs/i,
      /rendered\s+as\s+physics/i,
    ],
  },
  {
    id: "obvious-premise",
    appliesToKeywords: false,
    reason: "This states an obvious premise instead of a Filmtone-specific value.",
    rewrite: "Name the action or decision: choose a look, check it, export/save/share.",
    patterns: [
      /撮った写真/,
      /撮った後/,
      /撮影後/,
      /撮った端末/,
      /撮った素材/,
      /after[-\s]?shoot/i,
      /after you shoot/i,
      /device you shot/i,
      /capture device/i,
    ],
  },
  {
    id: "abstract-filler",
    appliesToKeywords: false,
    reason: "Mood language is too abstract for public Filmtone copy.",
    rewrite: "Replace it with the concrete change the user can make or verify.",
    patterns: [
      /安心/,
      /世界観/,
      /雰囲気/,
      /空気感/,
      /\bcinematic\b/i,
      /movie[-\s]?like/i,
      /film snapshots/i,
      /\batmosphere\b/i,
    ],
  },
];

const findings = [];
const findingIds = new Set();

function rel(file) {
  return path.relative(repoRoot, file);
}

function charCount(text) {
  return [...text].length;
}

function byteCount(text) {
  return Buffer.byteLength(text, "utf8");
}

function addFinding({ file, key, rule, matched, reason, rewrite }) {
  const id = [file, key, rule, matched].join("\u0000");
  if (findingIds.has(id)) return;
  findingIds.add(id);
  findings.push({
    file: typeof file === "string" ? file : rel(file),
    key,
    rule,
    matched,
    reason,
    rewrite,
  });
}

function isStyleSkipped(key) {
  const normalized = key.toLowerCase();
  return styleSkipKeyParts.some((part) => normalized.includes(part));
}

function isHighImpact(key) {
  const normalized = key.toLowerCase();
  return highImpactKeyParts.some((part) => normalized.includes(part));
}

function hasAny(text, words) {
  const lower = text.toLowerCase();
  return words.some((word) => lower.includes(word.toLowerCase()));
}

function countMatches(text, words) {
  const lower = text.toLowerCase();
  return words.filter((word) => lower.includes(word.toLowerCase())).length;
}

function surfaceCount(text) {
  const surfaces = [
    /Web\b/i,
    /browser/i,
    /ブラウザ/,
    /iPhone/i,
    /Mac\b/i,
    /macOS/i,
  ];
  return surfaces.filter((pattern) => pattern.test(text)).length;
}

function checkRulePatterns({ file, key, text, isKeywords }) {
  for (const rule of rules) {
    if (isKeywords && !rule.appliesToKeywords) continue;
    if (!isKeywords && isStyleSkipped(key) && rule.id !== "forbidden-claim") {
      continue;
    }
    for (const pattern of rule.patterns) {
      const match = text.match(pattern);
      if (match) {
        addFinding({
          file,
          key,
          rule: rule.id,
          matched: match[0],
          reason: rule.reason,
          rewrite: rule.rewrite,
        });
      }
    }
  }
}

function checkCategoryAsValue({ file, key, text, isKeywords }) {
  if (isKeywords || isStyleSkipped(key) || !isHighImpact(key)) return;
  const patterns = [
    /写真と動画/,
    /写真や動画/,
    /写真・動画/,
    /photos and videos/i,
    /photo and video/i,
    /photo\s*&\s*video/i,
  ];
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) {
      addFinding({
        file,
        key,
        rule: "category-as-value",
        matched: match[0],
        reason: "Media categories are being used as the value proposition.",
        rewrite:
          "Lead with Filmtone's action or decision path instead of category coverage.",
      });
    }
  }
}

function checkFeatureListCopy({ file, key, text, isKeywords }) {
  if (isKeywords || isStyleSkipped(key)) return;
  const featureCount = countMatches(text, featureWords);
  if (featureCount < 3 || hasAny(text, actionWords)) return;
  addFinding({
    file,
    key,
    rule: "feature-list-copy",
    matched: text.slice(0, 120),
    reason: "The line lists features without attaching them to an action or result.",
    rewrite: "Turn the list into a workflow: start, adjust, compare, export.",
  });
}

function checkSurfaceWithoutRole({ file, key, text, isKeywords }) {
  if (isKeywords || isStyleSkipped(key)) return;
  if (surfaceCount(text) < 2 || hasAny(text, roleWords)) return;
  addFinding({
    file,
    key,
    rule: "surface-without-role",
    matched: text.slice(0, 120),
    reason: "The line names surfaces without explaining what each one is for.",
    rewrite: "Assign roles: Web tries, iPhone saves/shares, Mac checks and exports.",
  });
}

function checkText({ file, key, text, isKeywords = false }) {
  if (!text.trim()) return;
  checkRulePatterns({ file, key, text, isKeywords });
  checkCategoryAsValue({ file, key, text, isKeywords });
  checkFeatureListCopy({ file, key, text, isKeywords });
  checkSurfaceWithoutRole({ file, key, text, isKeywords });
}

function walkStrings(value, prefix, visit) {
  if (typeof value === "string") {
    visit(prefix, value);
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value)) {
    walkStrings(child, prefix ? `${prefix}.${key}` : key, visit);
  }
}

function checkWebMessages() {
  for (const relativePath of webMessagePaths) {
    const fullPath = path.join(repoRoot, relativePath);
    const data = JSON.parse(fs.readFileSync(fullPath, "utf8"));
    const filmLab = data["film-lab"];
    walkStrings(filmLab, "film-lab", (key, text) => {
      checkText({ file: relativePath, key, text, isKeywords: true });
    });
    for (const namespace of ["lp", "features", "metadata", "jsonLd"]) {
      const section = filmLab?.[namespace];
      if (!section) continue;
      walkStrings(section, `film-lab.${namespace}`, (key, text) => {
        checkText({ file: relativePath, key, text });
      });
    }
  }
}

function checkMetadata() {
  for (const locale of metadataLocales) {
    for (const field of metadataFields) {
      const relativePath = `apps/capacitor-film-lab-ios/fastlane/metadata/${locale}/${field}.txt`;
      const fullPath = path.join(repoRoot, relativePath);
      const text = fs.readFileSync(fullPath, "utf8").trim();
      const limit = appStoreLimits.get(field);
      if (limit) {
        const count =
          limit.metric === "bytes" ? byteCount(text) : charCount(text);
        if (count > limit.max) {
          addFinding({
            file: relativePath,
            key: field,
            rule: "app-store-limit",
            matched: `${count}/${limit.max} ${limit.metric}`,
            reason: "The App Store field exceeds Apple's documented limit.",
            rewrite: "Shorten the field before upload.",
          });
        }
      }
      checkText({
        file: relativePath,
        key: field,
        text,
        isKeywords: field === "keywords",
      });
    }
  }
}

checkWebMessages();
checkMetadata();

if (findings.length === 0) {
  console.log("Filmtone copy quality check passed.");
  process.exit(0);
}

console.error(`Filmtone copy quality check failed: ${findings.length} issue(s).`);
for (const finding of findings) {
  console.error(
    [
      "",
      `${finding.file}`,
      `  key: ${finding.key}`,
      `  rule: ${finding.rule}`,
      `  matched: ${JSON.stringify(finding.matched)}`,
      `  reason: ${finding.reason}`,
      `  rewrite: ${finding.rewrite}`,
    ].join("\n"),
  );
}

process.exit(1);
