#!/usr/bin/env bash
# scripts/check-data.sh
#
# DATA-01 gate — no figure the site publishes is hand-typed.
#
# DATA-02 says the facts deciding *which records* a figure is computed over live on the
# records. DATA-01 is the other half: the figure itself must arrive from a record, never
# from a keystroke. A number typed into a component is a number nobody can check, and this
# site's entire claim is that its numbers can be checked.
#
# **The gate discriminates by destination, not by value** (DEC-017). A number bound for
# the layout engine is legal; a number that can reach a reader's eyes is a BLOCK unless it
# flowed in through an import. Two legal figure sources: `@plugdex/data` (measurement) and
# `@plugdex/registry` (stars and provenance, each carrying its SRC-01g receipt). The gate
# needs no special case for them — it blocks literals, and an import is not a literal.
#
# Violations:
#   DATA-01a  a numeric or digit-bearing literal in site TypeScript (or `.astro`
#             frontmatter) whose declaring context is not layout vocabulary
#   DATA-01b  a digit at a rendered position in an Astro template — a text node, an
#             expression literal, or a reader-facing attribute — regardless of what
#             identifier fed it
#   DATA-01c  a `content` declaration containing a digit: the one CSS property through
#             which a stylesheet can put a claim in front of a reader
#
# **What this gate is, and is not.** It was written believing that b closed what a only
# narrows — that blocking digits at every rendered position meant a spoofed constant could
# not reach a reader. That claim is withdrawn (DEC-017): eight channels have been driven
# past it in four review rounds, five into built output, and the uncovered set is
# generative rather than enumerable. `const gridColumns = 47` rendered as `{gridColumns}`
# still exits this gate 0.
#
# So: this is a developer-time lint. It narrows the channel from source to a reader, it
# catches the honest mistake, and it points at the line. DATA-01's guarantee is owed to
# PDX-021, which checks the rendered artifact, where the surface is finite. Do not restate
# the closed version of the claim here or anywhere else (CLAUDE.md's DATA-01 row says so
# explicitly, and this header was the last place still doing it).
#
# The failure mode that kills a gate like this is false positives, not an adversary — so
# the allowlist is short, syntactic, lives in one place, and may only be extended
# together with a golden case.
#
# ASSERT-01: the probe prints a sentinel on its success path, an unprefixed or empty
# capture is "the gate did not run" rather than a clean bill of health, and the scanned
# file count carries a floor.

set -uo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# shellcheck source=lib/gate-log.sh
source "$PROJECT_ROOT/scripts/lib/gate-log.sh"
gate_log_init "check-data" "-" "${*:-}"

SITE_DIR="packages/site"

if [[ ! -e "$SITE_DIR/package.json" ]]; then
  # No site package at all — the tree predates it. Every gate in this repository has to
  # have an answer before its subject exists, and "there is nothing to check" is one.
  echo -e "${GREEN}✅ DATA-01 SKIP — $SITE_DIR is not a package yet${NC}"
  exit 0
fi

if [[ ! -d "$SITE_DIR/src" ]]; then
  # But a site package with no sources is a deleted source tree wearing an absence, and
  # ASSERT-01 says a report of zero work is not a pass.
  echo -e "${RED}❌ DATA-01: $SITE_DIR is a package but has no src/ — the gate scanned nothing${NC}" >&2
  exit 1
fi

PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-data01.XXXXXX")"
# Chained, not replaced: `gate_log_init` installs its own EXIT trap and a bare
# `trap ... EXIT` here would drop this gate out of the OBS-01 log.
trap 'rc=$?; rm -rf "$PROBE_DIR"; gate_log_exit "$rc"' EXIT

# The two parsers are resolved from the site package rather than imported by bare name:
# the probe runs from a scratch directory, and `@astrojs/compiler` is a pinned
# devDependency of `packages/site` precisely so this resolution is declared rather than
# inherited from Astro's transitive tree (round 1 of the plan review caught that).
RESOLVED="$(node -e '
const { createRequire } = require("module");
const req = createRequire(process.argv[1] + "/package.json");
console.log(req.resolve("typescript"));
console.log(req.resolve("@astrojs/compiler"));
' "$PROJECT_ROOT/$SITE_DIR" 2>&1)"

if [[ "$RESOLVED" != /* ]]; then
  echo -e "${RED}❌ DATA-01: the gate's parsers are not resolvable from $SITE_DIR${NC}" >&2
  echo "$RESOLVED" | tail -3 >&2
  echo "both must be declared dependencies — run pnpm install" >&2
  exit 1
fi

export TS_MODULE="$(echo "$RESOLVED" | sed -n 1p)"
export COMPILER_MODULE="$(echo "$RESOLVED" | sed -n 2p)"
export SITE_DIR

cat > "$PROBE_DIR/scan.mjs" <<'PROBE'
/**
 * Scans the site source for figures that were typed rather than imported.
 *
 * Prints one sentinel line carrying the counts, then one indented line per violation.
 * The sentinel is what tells the caller the probe ran at all.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { pathToFileURL } from 'node:url';

const ts = (await import(pathToFileURL(process.env.TS_MODULE).href)).default;
const { parse } = await import(pathToFileURL(process.env.COMPILER_MODULE).href);

/**
 * The single source of truth for what a number is allowed to be about (DEC-017).
 *
 * Contexts, not values. Extending this list without adding a golden case in the same
 * change is the move that turns a gate into decoration.
 */
const LAYOUT_VOCABULARY =
  /(width|height|size|gap|column|row|radius|index|duration|delay|breakpoint|margin|padding|opacity|weight|scale)/i;

/**
 * Attributes a reader can actually read. Everything else in markup is machine-facing.
 *
 * `set:html` and `set:text` are here because they are rendered positions wearing an
 * attribute's clothes: Astro writes their value into the document verbatim. The PDX-004
 * report review got `set:html="47% of deliveries build"` all the way into `dist/` with
 * this gate exiting 0, which falsified DEC-017's claim that scanner 2 blocks digits at
 * every rendered position. `content` is here for `<meta>`, which is what a search result
 * or a link preview quotes.
 */
const READER_FACING_ATTRIBUTES = new Set([
  'alt',
  'title',
  'placeholder',
  'set:html',
  'set:text',
  // Every ARIA attribute whose value is spoken or shown. `aria-label` was here from the
  // start; the rest were not, and the PDX-004 report review put a figure through
  // `aria-description` and `aria-valuetext` into built output at round 2 — the same class
  // of miss as `set:html` at round 1. A screen reader is a reader.
  'aria-label',
  'aria-description',
  'aria-valuetext',
  'aria-roledescription',
  'aria-placeholder',
  'aria-braillelabel',
  'aria-brailleroledescription',
]);

/**
 * `<meta content>` is two different attributes wearing one name.
 *
 * `viewport` carries `initial-scale=1` and is instructions for the renderer; `description`
 * and the `og:`/`twitter:` family carry prose that a search result or a link preview
 * quotes to a reader, which makes a figure in one of them a published figure. Blocking
 * the whole attribute flagged this project's own viewport tag — a false positive, and
 * false positives are how a gate like this dies.
 */
const MACHINE_META = new Set([
  'viewport',
  'charset',
  'robots',
  'referrer',
  'theme-color',
  'color-scheme',
  'format-detection',
  'generator',
]);

const readerFacingMeta = ({ node, attribute }) => {
  if (attribute.name !== 'content' || node.name !== 'meta') return false;

  const key = (node.attributes ?? []).find((other) => other.name === 'name' || other.name === 'property');

  return !MACHINE_META.has((key?.value ?? '').toLowerCase());
};

/**
 * A digit, in the sense a reader means.
 *
 * `/\d/` is ASCII-only, and a text node of fullwidth numerals reached built output
 * because of it. `\p{N}` covers every Unicode numeric class — decimal, letter-numeric and
 * other-numeric — which is the smallest honest definition. Spelled-out figures ("about
 * half", "doubled") remain outside any digit scanner's reach at any strictness, and are
 * named in DEC-017 as the third residue rather than pretended away. That cross-reference
 * was false when it was written — DEC-017 listed two residues, not three — which goal
 * audit 4 caught. A pointer to documentation that does not say what the pointer claims is
 * the same defect this project prosecutes elsewhere, one scale down.
 */
const DIGIT = /\p{N}/u;

const violations = [];
let scanned = 0;

const walk = ({ dir }) => {
  const found = [];

  for (const name of readdirSync(dir)) {
    const path = join(dir, name);

    if (statSync(path).isDirectory()) {
      found.push(...walk({ dir: path }));
      continue;
    }

    if (/\.(ts|tsx|astro|css)$/.test(name)) found.push(path);
  }

  return found;
};

/** The frontmatter fence of an `.astro` file — TypeScript, by Astro's own definition. */
const frontmatterOf = ({ source }) => {
  if (!source.startsWith('---')) return { code: '', offset: 0 };

  const end = source.indexOf('\n---', 3);

  if (end === -1) return { code: '', offset: 0 };

  return { code: source.slice(3, end), offset: 3 };
};

const lineOf = ({ source, index }) => source.slice(0, index).split('\n').length;

// ---- scanner 1: code positions ----
const scanCode = ({ file, source, code, offset }) => {
  const sourceFile = ts.createSourceFile(file, code, ts.ScriptTarget.Latest, true);

  const contextName = (node) => {
    let current = node.parent;

    while (current) {
      // A JSX attribute is decided by the attribute, not by whatever declaration the climb
      // would eventually reach. Two reasons, both verified: the generic rule reaches the
      // component's own declaration and reports `Card`, which flags machine-facing
      // `className="grid-2"` for no reason; and the same accident *passes*
      // `title="47% of deliveries build"` inside a component called `LeaderboardRow`,
      // because `/row/i` is layout vocabulary. So the exemption is granted here and the
      // reader-facing case is blocked below, on the attribute itself.
      if (ts.isJsxAttribute(current)) {
        return '__exempt__';
      }

      if (ts.isVariableDeclaration(current) || ts.isPropertyAssignment(current) ||
          ts.isPropertyDeclaration(current) || ts.isParameter(current)) {
        return current.name?.getText?.(sourceFile) ?? '';
      }

      if (ts.isTypeNode(current) || ts.isElementAccessExpression(current) ||
          ts.isEnumMember(current)) {
        return '__exempt__';
      }

      // A slice-class argument is a position in a sequence, not a measurement. The list
      // is short and closed on purpose, and it deliberately excludes `toFixed`, which
      // formats a figure rather than indexing one.
      if (ts.isCallExpression(current) &&
          ts.isPropertyAccessExpression(current.expression) &&
          /^(slice|splice|substring|substr|at|charAt|indexOf|lastIndexOf|padStart|padEnd|repeat)$/
            .test(current.expression.name.getText(sourceFile))) {
        return '__exempt__';
      }

      // A comparison operand is a guard, not a figure: its result is a boolean and
      // nothing downstream can render it. This is a syntactic exemption rather than a
      // name one, so it does not widen the `const buildRate = 47` spoof beyond what
      // scanner 1 already permits. It does not close that spoof either — nothing here
      // does, and the sentence that used to claim scanner 2 caught it is withdrawn with
      // the rest (DEC-017).
      if (ts.isBinaryExpression(current) &&
          [ts.SyntaxKind.LessThanToken, ts.SyntaxKind.LessThanEqualsToken,
           ts.SyntaxKind.GreaterThanToken, ts.SyntaxKind.GreaterThanEqualsToken,
           ts.SyntaxKind.EqualsEqualsEqualsToken, ts.SyntaxKind.ExclamationEqualsEqualsToken,
           ts.SyntaxKind.EqualsEqualsToken, ts.SyntaxKind.ExclamationEqualsToken]
            .includes(current.operatorToken.kind)) {
        return '__exempt__';
      }

      current = current.parent;
    }

    return '';
  };

  const visit = (node) => {
    // A rendered position in JSX. `ts.isJsxText` is not `ts.isStringLiteral`, so the
    // generic rule below walks straight past `<p>47% of deliveries build</p>` — the hole a
    // `.tsx` walk would have shipped rather than closed (case 69).
    if (ts.isJsxText(node) && DIGIT.test(node.text)) {
      violations.push(
        `DATA-01b ${file}:${lineOf({ source, index: offset + node.getStart(sourceFile) })}: ` +
        `a digit is typed into rendered JSX text (${JSON.stringify(node.text.trim().slice(0, 40))})`,
      );
    }

    // The other rendered position in JSX, and the one the exemption above opens. Every
    // attribute string initializer is already a `StringLiteral`, so the generic rule reads
    // all of them with the wrong context; this branch decides them by name instead — the
    // same list scanner 2 uses on `.astro`, because a screen reader is a reader (case 70).
    if (ts.isJsxAttribute(node)) {
      const attribute = node.name.getText(sourceFile);
      const initializer = node.initializer?.getText?.(sourceFile) ?? '';

      if (READER_FACING_ATTRIBUTES.has(attribute) && DIGIT.test(initializer)) {
        violations.push(
          `DATA-01b ${file}:${lineOf({ source, index: offset + node.getStart(sourceFile) })}: ` +
          `a digit is typed into the reader-facing JSX attribute \`${attribute}\``,
        );
      }
    }

    const literal =
      ts.isNumericLiteral(node) ||
      ((ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) &&
        DIGIT.test(node.text));

    if (literal) {
      const name = contextName(node);

      if (name !== '__exempt__' && !LAYOUT_VOCABULARY.test(name)) {
        violations.push(
          `DATA-01a ${file}:${lineOf({ source, index: offset + node.getStart(sourceFile) })}: ` +
          `the literal ${JSON.stringify(node.getText(sourceFile))} is declared as ` +
          `${name ? `\`${name}\`` : 'an unnamed expression'}, which is not layout ` +
          `vocabulary — a figure must arrive from @plugdex/data or @plugdex/registry`,
        );
      }
    }

    ts.forEachChild(node, visit);
  };

  ts.forEachChild(sourceFile, visit);
};

// ---- scanner 2: rendered positions ----
const scanTemplate = async ({ file, source }) => {
  const { ast } = await parse(source);

  const visit = (node) => {
    // `<style>` and `<script>` bodies arrive as text nodes but are not rendered text.
    // A stylesheet is exempt wholesale except for `content`, which scanner 3 handles, and
    // a script's digits are machine-facing for the same reason a `class` attribute's are.
    // Reading them here would flag `z-index: 10`, and a gate that flags `z-index: 10` is
    // a gate somebody turns off within a week.
    if (node.type === 'element' && (node.name === 'style' || node.name === 'script')) {
      if (node.name === 'style') {
        for (const child of node.children ?? []) {
          scanStyles({ file, source: child.value ?? '' });
        }

        return;
      }

      // A script body is machine-facing only until it writes to the document. Two shapes
      // reached built output while this was exempt wholesale: a figure inside
      // `<script type="application/ld+json">`, which a search result quotes to a reader by
      // exactly the argument that made `<meta description>` reader-facing, and
      // `document.title = '… 47% …'`, which is the page's own name. The same string in a
      // `.ts` file was already a BLOCK, so the exemption was also inconsistent with itself.
      const type = (node.attributes ?? []).find((attribute) => attribute.name === 'type');
      const body = (node.children ?? []).map((child) => child.value ?? '').join('\n');

      if ((type?.value ?? '').includes('ld+json') && DIGIT.test(body)) {
        violations.push(
          `DATA-01b ${file}:${node.position?.start?.line ?? '?'}: a digit inside ` +
          `<script type="${type?.value}"> — structured data is quoted back to readers`,
        );
      } else {
        for (const [line, offset] of body.split('\n').map((value, index) => [value, index])) {
          if (/\b(document\.title|\.textContent|\.innerText|\.innerHTML|insertAdjacentHTML)\b/.test(line) &&
              DIGIT.test(line)) {
            violations.push(
              `DATA-01b ${file}:${(node.position?.start?.line ?? 0) + offset + 1}: a script ` +
              `writes a digit into the document (${JSON.stringify(line.trim().slice(0, 48))})`,
            );
          }
        }
      }

      return;
    }

    if (node.type === 'text' && DIGIT.test(node.value ?? '')) {
      violations.push(
        `DATA-01b ${file}:${node.position?.start?.line ?? '?'}: a digit is typed into ` +
        `rendered text (${JSON.stringify((node.value ?? '').trim().slice(0, 40))})`,
      );
    }

    if (node.type === 'expression') {
      for (const child of node.children ?? []) {
        if (child.type === 'text' && /(^|[^\w.])\p{N}/u.test(child.value ?? '')) {
          violations.push(
            `DATA-01b ${file}:${node.position?.start?.line ?? '?'}: a digit literal is ` +
            `rendered from an expression (${JSON.stringify((child.value ?? '').trim().slice(0, 40))})`,
          );
        }
      }
    }

    for (const attribute of node.attributes ?? []) {
      // `kind` distinguishes a quoted value from an expression; both are read the same
      // way by whoever ends up looking at the page, so both are scanned.
      const reads = READER_FACING_ATTRIBUTES.has(attribute.name) || readerFacingMeta({ node, attribute });

      if (reads && DIGIT.test(attribute.value ?? '')) {
        violations.push(
          `DATA-01b ${file}:${attribute.position?.start?.line ?? node.position?.start?.line ?? '?'}: ` +
          `a digit is typed into the reader-facing attribute \`${attribute.name}\``,
        );
      }
    }

    for (const child of node.children ?? []) visit(child);
  };

  visit(ast);
};

// ---- scanner 3: CSS ----
const scanStyles = ({ file, source }) => {
  const lines = source.split('\n');

  lines.forEach((line, index) => {
    if (!/(^|[\s{;])content\s*:/.test(line)) return;

    // Only the `content` declaration's own value, not the rest of the line: a single-line
    // rule like `content: ""; width: 12px;` is legitimate and was being blocked by the
    // width, which is the false-positive shape that gets a gate turned off.
    const declaration = line.split(';').find((part) => /(^|[\s{])content\s*:/.test(part)) ?? line;
    const value = declaration.split(':').slice(1).join(':');

    // `DIGIT`, not a private `/\d/`. This scanner kept an ASCII-only test after the other
    // two were widened, so `content: "４７％ builds"` — case 57's channel inside case 54's
    // — exited the gate 0 while the report called all five closed and pinned. Found by
    // report review round 4 by composing two fixes that were each correct alone.
    if (DIGIT.test(value)) {
      violations.push(
        `DATA-01c ${file}:${index + 1}: a \`content\` declaration carries a digit — it is ` +
        `the one property through which a stylesheet can put a claim in front of a reader`,
      );
      return;
    }

    // `content: attr(data-rate)` renders an attribute's value as text. Which attribute,
    // and what it holds, lives in another file this scanner does not read — so the
    // channel is refused rather than followed. The report review drove a figure into
    // `dist/` through exactly this pair with the gate green.
    // Every indirection, not only `attr()`. `var(--rate)` and `counter(rate)` each render
    // a value declared somewhere this scanner does not follow, and both were driven into
    // built output after `attr()` alone had been closed. The rule is the channel, not the
    // function name — otherwise the next CSS release reopens it.
    const indirection = value.match(/\b(attr|var|counter|counters|env)\s*\(/);

    if (indirection) {
      violations.push(
        `DATA-01c ${file}:${index + 1}: a \`content\` declaration renders a value through ` +
        `${indirection[1]}() — it comes from a declaration this scanner does not follow, ` +
        `so the channel is refused rather than followed`,
      );
    }
  });
};

for (const path of walk({ dir: join(process.env.SITE_DIR, 'src') }).sort()) {
  const file = relative(process.cwd(), path);
  const source = readFileSync(path, 'utf8');
  scanned += 1;

  if (path.endsWith('.css')) {
    scanStyles({ file, source });
    continue;
  }

  // `.tsx` routes here with `.ts`, and the branch is load-bearing rather than tidy: the
  // test below used to be `endsWith('.ts')` alone, which `.tsx` fails, so widening only the
  // walk regex sent every component down the Astro branch. The Astro parser reads a `.tsx`
  // as a template, reports its code lines as pseudo-text, and blocks `const markSize = 8`
  // as a rendered digit — the right verdict from the wrong scanner, and a false-positive
  // machine. `ts.createSourceFile` infers TSX from the file name, which cases 69-71 prove
  // by parsing JSX rather than by assertion.
  if (path.endsWith('.ts') || path.endsWith('.tsx')) {
    scanCode({ file, source, code: source, offset: 0 });
    continue;
  }

  const { code, offset } = frontmatterOf({ source });

  if (code) scanCode({ file, source, code, offset });

  await scanTemplate({ file, source });
  scanStyles({ file, source });
}

console.log('SENTINEL ' + JSON.stringify({ files: scanned, violations: violations.length }));

for (const line of violations) console.log('   ' + line);
PROBE

REPORT="$(node "$PROBE_DIR/scan.mjs" 2>&1)"

if [[ "$REPORT" != SENTINEL* ]]; then
  echo -e "${RED}❌ DATA-01: the gate produced no report — it did not run${NC}" >&2
  echo "$REPORT" | tail -5 >&2
  exit 1
fi

COUNTS="${REPORT%%$'\n'*}"
FILES="$(printf '%s' "${COUNTS#SENTINEL }" | python3 -c 'import json,sys; print(json.load(sys.stdin)["files"])')"
VIOLATIONS="$(printf '%s' "${COUNTS#SENTINEL }" | python3 -c 'import json,sys; print(json.load(sys.stdin)["violations"])')"

if [[ "$FILES" -lt 1 ]]; then
  echo -e "${RED}❌ DATA-01: $SITE_DIR/src holds no source file — the gate checked nothing${NC}" >&2
  exit 1
fi

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo -e "${RED}❌ DATA-01 BLOCK:${NC}" >&2
  printf '%s\n' "$REPORT" | tail -n +2 >&2
  exit 1
fi

echo -e "${GREEN}✅ DATA-01 PASS — $FILES site source files, every figure imported rather than typed${NC}"
