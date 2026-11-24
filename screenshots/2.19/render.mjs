// Renders the 2.19 Mac and Apple Vision Pro App Store screenshots in every language.
//
// Run from the repo root:   node screenshots/2.19/render.mjs [locale ...]
// Needs playwright-core (the one in store-screenshots/engine/node_modules: `npm install` there once)
// and Google Chrome installed.
//
// Reads screenshots/2.19/headlines.json  { locale: { mac: [{h, sub}], vision: [{h, sub}] } }
// and the English captures in screenshots/2.19/raw-mac and raw-vision, and writes
//   screenshots/2.19/mac/<locale>/01.png ... 05.png      (2880 x 1800)
//   screenshots/2.19/vision/<locale>/01.png ... 05.png   (3840 x 2160)
// Folder-per-locale is what tools/appstore-metadata/upload_metadata.py --screenshots expects.
import { createRequire } from 'node:module';
import { readFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..', '..');
// ENGINE_DIR can point at another checkout's store-screenshots/engine that already has node_modules
const ENGINE = process.env.ENGINE_DIR || join(ROOT, 'store-screenshots', 'engine');
const require = createRequire(join(ENGINE, 'package.json'));
const { chromium } = require('playwright-core');

const raw = (folder, name) => pathToFileURL(join(HERE, folder, name)).href;
const layouts = JSON.parse(readFileSync(join(HERE, 'layouts.json'), 'utf8'));
const headlines = JSON.parse(readFileSync(join(HERE, 'headlines.json'), 'utf8'));
const SIZE = { mac: [2880, 1800], vision: [3840, 2160] };

const locales = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(headlines);
const browser = await chromium.launch({ channel: 'chrome' });
const page = await browser.newPage({ deviceScaleFactor: 1 });
const shrunk = [];
for (const locale of locales) {
  for (const kind of ['mac', 'vision']) {
    const [W, H] = SIZE[kind];
    await page.setViewportSize({ width: W, height: H });
    const folder = join(HERE, kind, locale);
    mkdirSync(folder, { recursive: true });
    for (const [index, text] of headlines[locale][kind].entries()) {
      const images = layouts[kind][index].map(im => ({ ...im, src: raw(`raw-${kind}`, im.file) }));
      const spec = { kind, locale, h: text.h, sub: text.sub, images };
      await page.goto(pathToFileURL(join(HERE, 'frame.html')).href + '?spec=' + encodeURIComponent(JSON.stringify(spec)));
      await page.waitForSelector('body[data-ready="1"]', { timeout: 30000 });
      const scale = await page.evaluate(() => document.body.dataset.scale);
      if (Number(scale) < 1) shrunk.push(`${kind}/${locale}/${index + 1} at ${Math.round(scale * 100)}%`);
      await page.screenshot({ path: join(folder, `${String(index + 1).padStart(2, '0')}.png`), clip: { x: 0, y: 0, width: W, height: H } });
    }
  }
  console.log(`${locale}: done`);
}
await browser.close();
if (shrunk.length) console.log('Headline shrunk to fit: ' + shrunk.join(', '));
