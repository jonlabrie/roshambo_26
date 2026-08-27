#!/usr/bin/env node
// Wiki lint: index completeness, dead wikilinks, orphans, status language outside
// program/, log entry format, required frontmatter. See docs/wiki/schema.md.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, basename, resolve, dirname } from 'node:path';
import { pathToFileURL } from 'node:url';

const SHELVES = ['program', 'world', 'practice', 'systems'];
const LOG_KINDS = 'gate|ship|decision|drop|defect|migrate|lint|audit';
const STATUS_RE = /\b(NEXT IS|IN PROGRESS|RESUME HERE|OPEN:|BLOCKED|PARKED:|TODO:)/;

// ===== CURRENCY (checks 7-9) =====
// The structural checks above pass on a page that is internally contradictory and four
// buildings out of date -- that is exactly how the 2026-08-16 failures got through, and
// how a backlog entry went on describing a defect two days after it was fixed. See
// practice/wiki-currency.md. These three checks cannot read prose either; what they CAN do
// is notice that the ground under a page moved after the page last claimed to be current,
// and say so. A warning here means RE-READ, not "wrong".
//
// The escape hatch is real and deliberate: a stamp silences a warning without reading anything.
// That trade is the point -- an invisible rot becomes a visible prompt, and the prompt is cheap
// enough to survive being seen every session. Two fields, so the claim is at least legible:
// `updated:` says "I changed this", `checked:` says "I re-read this and it was right".

// Repo paths as the wiki writes them. Extensions run longest-first so .tsx is not clipped
// to .ts. Leading delimiter keeps `docs/foo.md` inside a wikilink or URL from matching.
// ⚠ `.superpowers` IS A ROOT, added 2026-08-27. Its absence made 11 citations across 7 pages
// invisible to check 8 -- one of them naming an SDD ledger that was never created -- and the
// directory was gitignored besides, so no clone could resolve any of them. A citation the
// checker cannot see is exactly as good as no citation.
const CITE_RE =
  /(?:^|[\s`(\[])((?:roblox|server|src|tools|docs|shared-fixtures|\.superpowers)\/[A-Za-z0-9._\/-]+\.(?:luau|tsx|ts|mjs|json|md))/g;

// The wiki cites Roblox files both ways -- `roblox/src/shared/X.luau` and, inside world/
// pages that never leave that tree, a bare `src/shared/X.luau`. Both must resolve or the
// check reports phantom dead citations on a third of the world shelf.
const CITE_PREFIXES = ['', 'roblox/'];

// How long a page may lag its cited code before staleness stops being a warning and starts being
// an error. Three days covers "I edited the code Friday and the wiki Monday"; it does not cover
// the eleven-day gaps that were sitting unactioned when this became blocking.
const STALE_GRACE_DAYS = 3;

// When did the page's BODY last move? Check 7 must not count a commit that ONLY bumped
// `checked:` -- adding that field commits the file, and if that counted as an edit the hatch
// would trip the very check it exists to satisfy. It did, on the day it shipped: seven pages
// failed 7fada0b for no reason but carrying the field it introduced.
//
// Measured from the diff rather than trusted from the frontmatter, so a commit that touches
// BOTH the body and `checked:` still counts as an edit -- which trusting `checked:` could not
// tell apart. Walks back only until it finds a real content change; a page whose last commit is
// an ordinary edit stops on the first step.
const CHECKED_LINE = /^[+-]checked: /;
export const gitContentDateOf = (absPath) => {
  try {
    const shas = execFileSync('git', ['log', '-20', '--format=%H %ad', '--date=short', '--', absPath], {
      cwd: dirname(absPath),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    })
      .trim()
      .split('\n')
      .filter(Boolean);
    for (const entry of shas) {
      const [sha, date] = entry.split(' ');
      const diff = execFileSync('git', ['show', '--unified=0', '--format=', sha, '--', absPath], {
        cwd: dirname(absPath),
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      const touched = diff
        .split('\n')
        .filter((l) => /^[+-]/.test(l) && !/^(\+\+\+|---)/.test(l));
      if (touched.some((l) => !CHECKED_LINE.test(l))) return date;
    }
    // Every commit in reach only bumped `checked:`. The body has not moved.
    return '';
  } catch {
    return '';
  }
};

export const gitDateOf = (absPath) => {
  try {
    return execFileSync('git', ['log', '-1', '--format=%ad', '--date=short', '--', absPath], {
      cwd: dirname(absPath),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
};


// ===== THE MECHANICAL SWEEPS (checks 10-13), added 2026-08-27 =====
// All four came out of a manual full-wiki audit that read 54 pages against the code. It found
// 13 rotten line citations, and verified 105 commit hashes and every cited symbol BY HAND.
// Automating exactly that makes the cheap pass SUFFICIENT for the mechanical layer, which is the
// point: reading is then reserved for prose, where it is the only thing that works.

// ⚠ A HASH IS NOT AN ASSET ID. The manual sweep's first run reported 36 "missing hashes"; 35
// were Roblox asset ids (pure decimal) and one an AWS service id (32 chars). A check that is
// wrong 35 times out of 36 is a check nobody reads, so bound the length and require a hex letter.
const HASH_RE = /`([0-9a-f]{7,12})`/g;
const commitExistsOf = (hash) => {
  try {
    execFileSync('git', ['cat-file', '-e', `${hash}^{commit}`], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
};

// Backticked code identifiers: `Foo.bar`, `Foo.bar.baz`, or a SHOUTY_CONSTANT.
const SYMBOL_RE = /`([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+|[A-Z][A-Z0-9_]{4,})`/g;
// A path's extension is not a symbol — `main.server.luau` must not be looked up as code.
const EXTENSIONS = new Set([
  'md', 'ts', 'tsx', 'luau', 'lua', 'json', 'mjs', 'cjs', 'js', 'py', 'yaml', 'yml', 'sh',
  'toml', 'csv', 'png', 'jpg', 'jpeg', 'fbx', 'blend', 'rbxm', 'rbxl', 'rbxlx', 'env',
  'nvmrc', 'gitignore', 'com', 'io', 'wav', 'm4a', 'mp4', 'zip', 'html', 'css', 'txt',
]);

// ⚠ A LINE NUMBER IS A MEASURABLE FACT TRANSCRIBED INTO PROSE (schema rule 9). In the
// 2026-08-27 audit, 8 of 9 citations in parked-defects.md pointed at the wrong place while the
// page carried a `checked:` stamp asserting a re-read — one landed on unrelated code entirely.
// Symbol names survive a refactor; line numbers do not, and a stale one spends a reader's trust.
const LINECITE_RE = /`([A-Za-z0-9_/.-]+\.(?:ts|tsx|luau|lua|mjs|cjs|js|json|py|yaml|yml)):([0-9]+(?:-[0-9]+)?)`/g;

// The wiki asserting a constant's value: `NAME` = 5 / `NAME = 5` / `NAME` is 5.
const CONST_RES = [
  /`([A-Z][A-Z0-9_]{3,})`\s*(?:=|is|of|at)\s*`?(-?[0-9]+(?:\.[0-9]+)?)`?/g,
  /`([A-Z][A-Z0-9_]{3,})\s*=\s*(-?[0-9]+(?:\.[0-9]+)?)`/g,
];

const SRC_EXT = /\.(ts|tsx|luau|mjs|cjs|js|py)$/;
const SKIP_DIR = new Set(['node_modules', 'dist', '.git', 'build', '.worktrees', 'coverage']);
// ⚠ THIS LINT'S OWN TEST FILE IS NOT REPO SOURCE, and reading it as source silently disarmed
// checks 11 and 12. `lint.test.mjs` builds fake wikis out of fake source strings, and it quotes
// the real defects it was written from -- including the comment "MIN_SHORO_GAP = 5.0 was a floor
// invented here". Check 12 then found a 5.0 for MIN_SHORO_GAP, matched the wiki's value, and
// passed the page. The check the test was guarding was defeated by the test that guards it, and
// the page it was written about never needed its exemption. Found 2026-08-27: excluding this one
// file turns check 12 back on with exactly one hit, the hit the test predicted.
// Only the TEST is excluded -- `lint.mjs` itself is real source, and backlog.md legitimately
// cites `CITE_RE`/`CITE_PREFIXES` from it.
const sourceTextOf = (repoRoot) => {
  const selfTest = join(repoRoot, 'tools', 'wiki', 'lint.test.mjs');
  let out = '';
  const walk = (dir) => {
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      if (e.isDirectory()) {
        if (!SKIP_DIR.has(e.name)) walk(join(dir, e.name));
      } else if (SRC_EXT.test(e.name) && join(dir, e.name) !== selfTest) {
        try {
          out += readFileSync(join(dir, e.name), 'utf8') + '\n';
        } catch {
          /* unreadable file is not a wiki defect */
        }
      }
    }
  };
  walk(repoRoot);
  return out;
};

export function lint(root, opts = {}) {
  const errors = [];
  const warnings = [];
  // Both injectable so the tests can build a wiki in a tmpdir with no git and no repo.
  const repoRoot = opts.repoRoot ?? resolve(root, '..', '..');
  // Is this path deliberately absent — gitignored rather than missing? Asked of git rather than
// guessed from a name list, so a new local-only file needs no edit here.
const ignoreCache = new Map();
function isIgnored(rel) {
  if (ignoreCache.has(rel)) return ignoreCache.get(rel);
  let ignored = false;
  try {
    execFileSync('git', ['check-ignore', '-q', rel], { cwd: repoRoot, stdio: 'ignore' });
    ignored = true;
  } catch (err) {
    // ⚠ DISTINGUISH "git answered no" FROM "this function is broken". The first version of this
    // called `execSync`, which the module does not import, and its own catch swallowed the
    // ReferenceError and reported "not ignored" — the check silently did nothing at all. So a
    // programming error must still escape.
    //
    // But git legitimately fails in two ways here: exit 1 (the path is not ignored) and exit 128
    // (repoRoot is not a git repo — the lint is INJECTABLE precisely so tests can run against a
    // tmpdir with no git, and an over-strict rethrow broke four of them). Both mean "not ignored";
    // an error with no numeric status at all is a bug in this file and is rethrown.
    if (typeof err?.status !== 'number' && err?.code !== 'ENOENT') throw err;
    ignored = false;
  }
  ignoreCache.set(rel, ignored);
  return ignored;
}

const gitDate = opts.gitDate ?? gitDateOf;
  // A test that injects only `gitDate` is stating when the page moved and means it to count
  // as content; falling back keeps every pre-existing test honest rather than no-op.
  const gitContentDate = opts.gitContentDate ?? opts.gitDate ?? gitContentDateOf;
  const commitExists = opts.commitExists ?? commitExistsOf;
  // Lazy: a wiki-only test never pays for a repo walk, and one walk serves every page.
  let _src = null;
  const sourceText = () => (_src ??= opts.sourceText ? opts.sourceText() : sourceTextOf(repoRoot));

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
    if (/^checked:/m.test(p.text) && !/^checked: \d{4}-\d{2}-\d{2}$/m.test(p.text))
      errors.push(`${p.rel}: bad frontmatter 'checked' (want YYYY-MM-DD)`);
    // 5. orphans (index links don't count) — warning only
    const inbound = pages.some((q) => q !== p && (q.text.includes(`[[${p.name}]]`) || q.text.includes(`[[${p.name}|`)));
    if (!inbound) warnings.push(`${p.rel}: no inbound wikilinks (orphan)`);

    // ⚠ Every sweep below honours `<!-- lint-ok` ON THE LINE. The audit hit exactly one false
    // positive — a page CORRECTLY narrating a retired wrong value — and a check that punishes
    // good writing gets switched off, taking the true positives with it.
    const linesOf = p.text.split('\n');
    const exemptLine = (idx) => linesOf[idx]?.includes('lint-ok');
    const lineIndexOf = (needle) => linesOf.findIndex((l) => l.includes(needle));

    // 10. every cited commit hash resolves
    for (const m of p.text.matchAll(HASH_RE)) {
      const h = m[1];
      if (!/[a-f]/.test(h)) continue; // pure decimal is an asset id, not a hash
      if (exemptLine(lineIndexOf(m[0]))) continue;
      if (!commitExists(h)) errors.push(`${p.rel}: cited commit \`${h}\` does not resolve`);
    }

    // 11. every cited code symbol exists somewhere in the repo
    // ⚠ A ROBLOX DATAMODEL PATH IS NOT A CODE SYMBOL. `ServerStorage.RetiredLegacyTeahouses`,
    // `Lighting.Atmosphere`, `CanyonWorld.Water.FallsAudio` live in the PLACE, which git cannot
    // see — that is the entire reason world/ pages exist. The first run of this check reported
    // 15 errors of which 13 were exactly that, which is the "35 of 36" failure the comment above
    // warns about, shipped anyway. Instance paths and event channels carry PascalCase leaves;
    // functions and methods carry lowerCamelCase. So a dotted symbol is only looked up when its
    // leaf starts lowercase. SHOUTY_CONSTANTS are always checked — they are never instances.
    for (const m of p.text.matchAll(SYMBOL_RE)) {
      const sym = m[1];
      const leaf = sym.includes('.') ? sym.split('.').pop() : sym;
      if (EXTENSIONS.has(leaf)) continue; // it is a filename, not a symbol
      if (sym.includes('.') && !/^[a-z]/.test(leaf)) continue; // DataModel path or event channel
      if (exemptLine(lineIndexOf(m[0]))) continue;
      if (!sourceText().includes(leaf))
        errors.push(`${p.rel}: cited symbol \`${sym}\` exists nowhere in the repo`);
    }

    // 12. a constant the wiki gives a value for must match the code
    for (const re of CONST_RES) {
      for (const m of p.text.matchAll(re)) {
        const [, name, val] = m;
        if (exemptLine(lineIndexOf(m[0]))) continue;
        const found = [...sourceText().matchAll(
          new RegExp(`\\b${name}\\b\\s*(?::\\s*[A-Za-z<>\\[\\]{}, ]+)?\\s*=\\s*(-?[0-9]+(?:\\.[0-9]+)?)`, 'g')
        )].map((x) => x[1]);
        if (!found.length) continue; // not a constant we can see; nothing to compare
        if (!found.some((g) => Math.abs(Number(g) - Number(val)) < 1e-9))
          errors.push(
            `${p.rel}: says ${name} = ${val}, code has ${[...new Set(found)].join('/')}` +
              ` — fix it, or add <!-- lint-ok --> if the page is narrating a retired value`
          );
      }
    }

    // 13. no line-number citations — schema rule 9
    for (const m of p.text.matchAll(LINECITE_RE)) {
      if (exemptLine(lineIndexOf(m[0]))) continue;
      errors.push(
        `${p.rel}: \`${m[1]}:${m[2]}\` cites a line number — name the symbol instead;` +
          ` line numbers rot silently (8 of 9 were wrong in the 2026-08-27 audit)`
      );
    }

    const updated = (p.text.match(/^updated: (\d{4}-\d{2}-\d{2})$/m) ?? [])[1];
    // Optional. "I re-read this and it was still true" — a different claim from "I changed it".
    const checked = (p.text.match(/^checked: (\d{4}-\d{2}-\d{2})$/m) ?? [])[1];
    if (!updated) continue; // check 4 already reported the bad frontmatter

    // 7. the page's own edits outran its `updated:` — schema rule 6, mechanically
    const pageCommitted = gitContentDate(p.path);
    if (pageCommitted && pageCommitted > updated)
      errors.push(`${p.rel}: committed ${pageCommitted} but frontmatter says updated: ${updated} — bump it`);

    // A page sometimes cites a path in order to say it is GONE -- studio-tooling's Flags
    // section names a Studio mirror that was never committed. That is the note's whole
    // point, so `<!-- lint-ok -->` on the line exempts the citation rather than the page.
    const exempt = new Set(
      p.text
        .split('\n')
        .filter((l) => l.includes('lint-ok'))
        .flatMap((l) => [...l.matchAll(CITE_RE)].map((m) => m[1]))
    );
    const cited = new Set([...p.text.matchAll(CITE_RE)].map((m) => m[1]));
    for (const cite of cited) {
      const abs = CITE_PREFIXES.map((pre) => join(repoRoot, pre + cite)).find(existsSync);
      // 8. dead code citation — the same defect as a dead wikilink, pointed at the repo
      if (!abs) {
        // ⚠ A GITIGNORED FILE IS NOT A DEAD CITATION. `SecretsLocal.luau` is deliberately
        // local-only and deliberately documented, so it exists in the developer's checkout and in
        // no other. Running this lint from a fresh clone or a git worktree therefore reported an
        // error for a page that was correct — and a lint that fails in a VALID workspace teaches
        // people to ignore lint, which costs more than the check is worth.
        if (!exempt.has(cite) && !isIgnored(cite)) errors.push(`${p.rel}: dead code citation ${cite}`);
        continue;
      }
      // 9. the ground moved under a page that still claims to be current
      //
      // ⚠ THIS BLOCKS AS OF 2026-08-26, and the reason is measured rather than felt. It was a
      // WARNING, and warnings do not get cleared: fifteen had accumulated, eight of them on pages
      // untouched for eleven days, while 60 of the previous 77 wiki commits were CORRECTIONS of
      // things already written. Detection was never the gap — consequence was.
      //
      // `checked:` is the escape hatch and it is deliberately not `updated:`. Bumping `updated:`
      // to silence this would claim the page CHANGED when all that happened is somebody re-read it
      // and found it still true. Two different facts, two different fields.
      //
      // The GRACE window exists so ordinary same-session work does not trip it — you edit code and
      // the wiki in one sitting, in either order. Past it, a page that has not been looked at while
      // its ground moved is an error, because that is exactly the state every drift in this repo
      // was found in.
      const moved = gitDate(abs);
      const verified = checked && checked > updated ? checked : updated;
      if (moved && moved > verified) {
        const staleDays = Math.floor((Date.parse(moved) - Date.parse(verified)) / 86400000);
        const msg =
          `${p.rel}: re-read — ${cite} changed ${moved}, page verified ${verified}` +
          ` (${staleDays}d). Re-read it, then bump 'updated:' if you changed it or add` +
          ` 'checked: YYYY-MM-DD' if it was already right.`;
        if (staleDays > STALE_GRACE_DAYS) errors.push(msg);
        else warnings.push(msg);
      }
    }
  }

  // 6. log format
  const log = readFileSync(join(root, 'log.md'), 'utf8');
  const entryRe = new RegExp(`^## \\[\\d{4}-\\d{2}-\\d{2}\\] (${LOG_KINDS}) \\| .+`);
  for (const line of log.split('\n').filter((l) => l.startsWith('## ')))
    if (!entryRe.test(line)) errors.push(`log.md: malformed entry "${line}"`);

  return { errors, warnings, pageCount: pages.length };
}

// ⚠ A SHALLOW CLONE CANNOT ANSWER ANY OF THE GIT CHECKS, AND FAILS THEM ALL AT ONCE.
// Checks 7-10 ask git when a file last changed and whether a hash resolves. In a shallow clone
// (`git clone --depth`, which is what CI and the hosted agent containers do) every commit before
// the boundary is absent, so every cited hash "does not resolve" and every file appears to have
// changed on the boundary commit's date -- it is one synthetic squash of the whole tree.
// Measured 2026-08-27 in a depth-61 container: 231 errors, of which 231 were phantom. The full
// clone reported 0.
// A lint that is wrong 231 times teaches people to ignore lint -- the same reasoning as the
// gitignored-citation note above -- so refuse to render a verdict rather than render a false one.
const isShallow = () => {
  try {
    return (
      execFileSync('git', ['rev-parse', '--is-shallow-repository'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }).trim() === 'true'
    );
  } catch {
    return false; // not a git repo at all; the git checks degrade to no-ops on their own
  }
};

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const root = process.argv[2] ?? 'docs/wiki';
  if (isShallow()) {
    console.log(
      'ERROR shallow clone — the git-history checks (7-10) cannot run here and would report\n' +
        '      hundreds of phantom errors. Deepen the clone first:\n' +
        '\n' +
        '        git fetch --unshallow origin\n'
    );
    process.exit(1);
  }
  const { errors, warnings, pageCount } = lint(root);
  for (const w of warnings) console.log(`WARN  ${w}`);
  for (const e of errors) console.log(`ERROR ${e}`);
  console.log(`${errors.length} error(s), ${warnings.length} warning(s) across ${pageCount} pages`);
  process.exit(errors.length ? 1 : 0);
}
