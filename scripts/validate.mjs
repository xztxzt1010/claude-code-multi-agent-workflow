import { readFile, readdir, stat } from 'node:fs/promises';
import { dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import process from 'node:process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const agentContracts = {
  'premise-overturner': 'verdict:',
  'assumption-challenger': 'risk:',
  'test-designer': 'test_plan:',
  'metric-gate': 'metrics:',
  'rollback-planner': 'rollback_steps:',
  'range-creep-guardian': 'verdict:'
};
const required = [
  'README.md', 'LICENSE', 'CLAUDE.md', 'package.json',
  'skills/three-review/SKILL.md', 'skills/six-role-drill/SKILL.md',
  'docs/architecture.md', 'docs/handoff-protocol.md', 'docs/security.md', 'docs/evaluation.md',
  'evals/cases.json', 'scripts/install.ps1', 'scripts/uninstall.ps1',
  'scripts/install.sh', 'scripts/uninstall.sh'
];
const errors = [];

async function text(path) {
  return (await readFile(join(root, path), 'utf8')).replace(/\r\n?/g, '\n');
}

async function exists(path) {
  try { await stat(join(root, path)); return true; } catch { return false; }
}

async function walk(dir = root) {
  const result = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules' || entry.name === 'results') continue;
    const path = join(dir, entry.name);
    if (entry.isDirectory()) result.push(...await walk(path));
    else result.push(path);
  }
  return result;
}

for (const path of required) {
  if (!await exists(path)) errors.push(`missing required file: ${path}`);
}

for (const [name, outputKey] of Object.entries(agentContracts)) {
  const path = `agents/${name}.md`;
  if (!await exists(path)) {
    errors.push(`missing agent: ${path}`);
    continue;
  }
  const source = await text(path);
  if (!source.startsWith('---\n') || !source.includes(`\nname: ${name}\n`)) {
    errors.push(`invalid frontmatter name: ${path}`);
  }
  if (!source.includes('\ndescription: ') || !source.includes('\ntools: ')) {
    errors.push(`incomplete frontmatter: ${path}`);
  }
  if (!source.includes(outputKey)) errors.push(`missing output key ${outputKey} in ${path}`);
}

const cases = JSON.parse(await text('evals/cases.json'));
if (!Array.isArray(cases) || cases.length < 20) errors.push('evaluation set must contain at least 20 cases');
const ids = new Set();
for (const item of cases) {
  if (!item.id || ids.has(item.id)) errors.push(`missing or duplicate case id: ${item.id}`);
  ids.add(item.id);
  if (!item.prompt || !Array.isArray(item.expectedRoles) || !Array.isArray(item.mustDetect)) {
    errors.push(`invalid evaluation case: ${item.id}`);
  }
  for (const role of item.expectedRoles ?? []) {
    if (!(role in agentContracts)) errors.push(`unknown role ${role} in ${item.id}`);
  }
}

const files = await walk();
const tokenPatterns = [
  /ghp_[A-Za-z0-9]{20,}/g,
  /github_pat_[A-Za-z0-9_]{20,}/g,
  /sk-[A-Za-z0-9]{20,}/g,
  /-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----/g,
  /(?:ANTHROPIC|OPENAI|GITHUB)_API_KEY\s*=\s*[^<\s][^\s]*/g
];

for (const file of files) {
  const extension = extname(file).toLowerCase();
  if (!['.md', '.json', '.yml', '.yaml', '.js', '.mjs', '.ps1', '.sh', ''].includes(extension)) continue;
  const source = (await readFile(file, 'utf8')).replace(/\r\n?/g, '\n');
  for (const pattern of tokenPatterns) {
    pattern.lastIndex = 0;
    if (pattern.test(source)) errors.push(`possible secret in ${relative(root, file)} matching ${pattern.source}`);
  }
}

for (const file of files.filter((path) => extname(path).toLowerCase() === '.md')) {
  const source = (await readFile(file, 'utf8')).replace(/\r\n?/g, '\n');
  const links = [...source.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)].map((match) => match[1]);
  for (const link of links) {
    if (/^(?:https?:|mailto:|#)/.test(link)) continue;
    const target = resolve(dirname(file), decodeURIComponent(link.split('#')[0]));
    try { await stat(target); } catch { errors.push(`broken local link in ${relative(root, file)}: ${link}`); }
  }
}

if (errors.length) {
  console.error(`Validation failed (${errors.length}):`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Validation passed: ${Object.keys(agentContracts).length} agents, ${cases.length} eval cases, ${files.length} files scanned.`);
