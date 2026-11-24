// Builds the 2.19 App Preview videos (Mac 1920x1080, Apple Vision Pro 3840x2160) in every language.
//
// Run from the repo root:
//   ENGINE_DIR=<checkout with store-screenshots/engine/node_modules> node screenshots/2.19/preview/make_preview.mjs [locale ...]
// Needs playwright-core + Google Chrome (for the caption frames) and ffmpeg.
//
// Inputs (English app footage, recorded once):
//   preview/footage/mac-a.mov, mac-b.mov       Then & Now (old map, year steps) and Time Walk
//   preview/footage/vision-a.mp4, vision-b.mp4 the same on the visionOS simulator
// Output: preview/out/<mac|vision>/<locale>.mp4  (H.264, 30 fps, silent stereo AAC track, about 25 s)
// Only the captions change per language; headlines come from ../headlines.json (Mac 2 and 3, Vision 5).
import { createRequire } from 'node:module';
import { readFileSync, mkdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..', '..', '..');
const ENGINE = process.env.ENGINE_DIR || join(ROOT, 'store-screenshots', 'engine');
const require = createRequire(join(ENGINE, 'package.json'));
const { chromium } = require('playwright-core');

const headlines = JSON.parse(readFileSync(join(HERE, '..', 'headlines.json'), 'utf8'));
const icon = pathToFileURL(join(ROOT, 'Stamped! A City Passport', 'Assets.xcassets', 'AppIcon.appiconset', 'mac-icon-1024.png')).href;
const locales = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(headlines);

// How long each part lasts, in seconds (App Store allows 15-30 s)
const PART_A = 11, PART_B = 11.5, END = 4;
const KINDS = {
  mac:    { scale: 1, W: 1920, H: 1080, a: 'mac-a.mov', b: 'mac-b.mov' },
  vision: { scale: 2, W: 3840, H: 2160, a: 'vision-a.mp4', b: 'vision-b.mp4' },
};

// 1. Caption frames (PNG) for every language
const browser = await chromium.launch({ channel: 'chrome' });
const page = await browser.newPage({ deviceScaleFactor: 1 });
for (const locale of locales) {
  const text = headlines[locale];
  const cards = { a: { mode: 'band', h: text.mac[1].h }, b: { mode: 'band', h: text.mac[2].h }, end: { mode: 'end', h: text.vision[4].h, icon } };
  for (const [kind, k] of Object.entries(KINDS)) {
    await page.setViewportSize({ width: k.W, height: k.H });
    const folder = join(HERE, 'cards', kind, locale);
    mkdirSync(folder, { recursive: true });
    for (const [name, card] of Object.entries(cards)) {
      const spec = { ...card, locale, scale: k.scale };
      await page.goto(pathToFileURL(join(HERE, 'card.html')).href + '?spec=' + encodeURIComponent(JSON.stringify(spec)));
      await page.waitForSelector('body[data-ready="1"]', { timeout: 30000 });
      await page.screenshot({ path: join(folder, `${name}.png`), clip: { x: 0, y: 0, width: k.W, height: k.H } });
    }
  }
}
await browser.close();

// 2. Videos: footage scaled into the box on the caption frame, then the end card, with a short fade between parts
for (const [kind, k] of Object.entries(KINDS)) {
  const footA = join(HERE, 'footage', k.a), footB = join(HERE, 'footage', k.b);
  if (!existsSync(footA) || !existsSync(footB)) { console.log(`${kind}: no footage yet, captions only`); continue; }
  const s = k.scale, box = `${1440 * s}:${810 * s}`, at = `${240 * s}:${250 * s}`;
  for (const locale of locales) {
    const cards = join(HERE, 'cards', kind, locale);
    mkdirSync(join(HERE, 'out', kind), { recursive: true });
    const filter = [
      `[1:v]trim=0:${PART_A},setpts=PTS-STARTPTS,fps=30,scale=${box}:flags=lanczos[fa]`,
      `[0:v][fa]overlay=${at}:shortest=1,format=yuv420p,settb=1/30,fade=t=in:d=0.4[va]`,
      `[3:v]trim=0:${PART_B},setpts=PTS-STARTPTS,fps=30,scale=${box}:flags=lanczos[fb]`,
      `[2:v][fb]overlay=${at}:shortest=1,format=yuv420p,settb=1/30[vb]`,
      `[4:v]fps=30,format=yuv420p,settb=1/30,fade=t=out:st=${END - 0.5}:d=0.5[ve]`,
      `[va][vb]xfade=transition=fade:duration=0.5:offset=${PART_A - 0.5}[vab]`,
      `[vab][ve]xfade=transition=fade:duration=0.5:offset=${PART_A + PART_B - 1},format=yuv420p[v]`,
    ].join(';');
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error',
      '-framerate', '30', '-loop', '1', '-t', String(PART_A), '-i', join(cards, 'a.png'), '-i', footA,
      '-framerate', '30', '-loop', '1', '-t', String(PART_B), '-i', join(cards, 'b.png'), '-i', footB,
      '-framerate', '30', '-loop', '1', '-t', String(END), '-i', join(cards, 'end.png'),
      // App Store previews need an audio track: a silent stereo one
      '-f', 'lavfi', '-t', String(PART_A + PART_B + END - 1), '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
      '-filter_complex', filter, '-map', '[v]', '-map', '5:a',
      '-c:v', 'libx264', '-profile:v', 'high', '-preset', 'slow', '-crf', '18', '-r', '30',
      '-c:a', 'aac', '-b:a', '256k', '-shortest', '-movflags', '+faststart',
      join(HERE, 'out', kind, `${locale}.mp4`)]);
    console.log(`${kind}/${locale}: done`);
  }
}
