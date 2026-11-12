// Turns the app screens rendered by app/test/store_assets/web_screens_test.dart
// (build/web-screens/*.png, run tool/web_screens.ps1 or .sh) into the WebP files
// the site shows (public/screens/). Only the WebP files are committed.
import { mkdirSync, readdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const web = join(dirname(fileURLToPath(import.meta.url)), '..');
const from = join(web, '..', 'build', 'web-screens');
const to = join(web, 'public', 'screens');

// Shown at most 360 CSS px wide: 720 px covers a 2x display.
const WIDTH = 720;

const pngs = readdirSync(from).filter((name) => name.endsWith('.png'));
if (pngs.length === 0) throw new Error(`No PNGs in ${from}. Run tool/web_screens first.`);

rmSync(to, { recursive: true, force: true });
mkdirSync(to, { recursive: true });
for (const name of pngs) {
  const out = join(to, name.replace(/\.png$/, '.webp'));
  const info = await sharp(join(from, name))
    .resize({ width: WIDTH })
    .webp({ quality: 86, effort: 6 })
    .toFile(out);
  console.log(`${name} -> public/screens/${name.replace(/\.png$/, '.webp')} ${info.width}x${info.height} ${Math.round(info.size / 1024)} KB`);
}
