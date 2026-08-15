#!/usr/bin/env node
// Wiki lint: index completeness, dead wikilinks, orphans, status language outside
// program/, log entry format, required frontmatter. See docs/wiki/schema.md.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join, basename } from 'node:path';
import { pathToFileURL } from 'node:url';

const SHELVES = ['program', 'world', 'practice', 'systems'];
const LOG_KINDS = 'gate|ship|decision|drop|defect|migrate|lint|audit';
const STATUS_RE = /\b(NEXT IS|IN PROGRESS|RESUME HERE|OPEN:|BLOCKED|PARKED:|TODO:)\b/;

export function lint(root) {
  const errors = [];
  const warnings = [];

  const pages = [];
  for (const shelf of SHELVES) {
    const dir = join(root, shelf);
    if (!existsSync(dir)) continue;
    for (const f of readdirSync(dir).filter((f) => f.endsWith('.md'))) {
      const path = join(dir, f);
      pages.push({ shelf, name: basename(f, '.md'), rel: `${shelf}/${f}`, path, text: readFileSync(path, 'utf8') });
    }
  }
  const names = new Set(pages.map((p) => p.name));

  // 1. index completeness both ways
  const index = readFileSync(join(root, 'index.md'), 'utf8');
  for (const p of pages) if (!index.includes(p.rel)) errors.push(`index.md missing ${p.rel}`);
  for (const m of index.matchAll(/\(((?:program|world|practice|systems)\/[^)]+\.md)\)/g))
    if (!existsSync(join(root, m[1]))) errors.push(`index.md links to missing ${m[1]}`);

  for (const p of pages) {
    // 2. dead wikilinks
    for (const m of p.text.matchAll(/\[\[([^\]|#]+)/g)) {
      const target = m[1].trim();
      if (!names.has(target)) errors.push(`${p.rel}: dead wikilink [[${target}]]`);
    }
    // 3. status confinement
    if (p.shelf !== 'program') {
      if (/^status:/m.test(p.text)) errors.push(`${p.rel}: frontmatter 'status' outside program/`);
      const line = p.text.split('\n').find((l) => STATUS_RE.test(l));
      if (line) errors.push(`${p.rel}: status language outside program/: "${line.trim()}"`);
    }
    // 4. frontmatter
    if (!/^shelf: (program|world|practice|systems)$/m.test(p.text)) errors.push(`${p.rel}: missing/bad frontmatter 'shelf'`);
    if (!/^updated: \d{4}-\d{2}-\d{2}$/m.test(p.text)) errors.push(`${p.rel}: missing/bad frontmatter 'updated'`);
    // 5. orphans (index links don't count) — warning only
    const inbound = pages.some((q) => q !== p && (q.text.includes(`[[${p.name}]]`) || q.text.includes(`[[${p.name}|`)));
    if (!inbound) warnings.push(`${p.rel}: no inbound wikilinks (orphan)`);
  }

  // 6. log format
  const log = readFileSync(join(root, 'log.md'), 'utf8');
  const entryRe = new RegExp(`^## \\[\\d{4}-\\d{2}-\\d{2}\\] (${LOG_KINDS}) \\| .+`);
  for (const line of log.split('\n').filter((l) => l.startsWith('## ')))
    if (!entryRe.test(line)) errors.push(`log.md: malformed entry "${line}"`);

  return { errors, warnings, pageCount: pages.length };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const root = process.argv[2] ?? 'docs/wiki';
  const { errors, warnings, pageCount } = lint(root);
  for (const w of warnings) console.log(`WARN  ${w}`);
  for (const e of errors) console.log(`ERROR ${e}`);
  console.log(`${errors.length} error(s), ${warnings.length} warning(s) across ${pageCount} pages`);
  process.exit(errors.length ? 1 : 0);
}
