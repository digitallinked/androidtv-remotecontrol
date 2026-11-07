// Copies the release docs the site publishes into web/content, so a deploy of
// web/ alone has them. docs/release stays the source; a test fails on drift.
import { copyFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const web = join(dirname(fileURLToPath(import.meta.url)), '..');
const release = join(web, '..', 'docs', 'release');

for (const [from, to] of [
  ['placeholders.json', 'placeholders.json'],
  ['legal/privacy-policy.md', 'privacy-policy.md'],
  ['legal/terms.md', 'terms.md'],
]) {
  const source = join(release, from);
  if (!existsSync(source)) throw new Error(`Missing ${source}`);
  copyFileSync(source, join(web, 'content', to));
  console.log(`Copied ${from}`);
}
