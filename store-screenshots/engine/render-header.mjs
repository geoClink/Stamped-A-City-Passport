import { createRequire } from 'module'; import path from 'path'; import { pathToFileURL, fileURLToPath } from 'url';
const req = createRequire(import.meta.url); const { chromium } = req('playwright-core');
const [src, out] = process.argv.slice(2);
let b; for (const channel of ['chrome', undefined]) { try { b = await chromium.launch({ channel, args: ['--allow-file-access-from-files'] }); break; } catch {} }
const p = await b.newPage({ viewport: { width: 3072, height: 1728 } });
await p.goto(pathToFileURL(path.resolve(src)).href, { waitUntil: 'networkidle' });
await p.waitForSelector('body[data-ready]', { timeout: 60000 });
await p.waitForTimeout(800); await p.screenshot(); await p.waitForTimeout(300);
await p.screenshot({ path: out }); await b.close(); console.log('ok', out);
