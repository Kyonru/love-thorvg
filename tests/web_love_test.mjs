import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {extname, resolve, sep} from 'node:path';
import process from 'node:process';
import {chromium} from 'playwright';

const root = resolve(process.argv[2] || 'dist/web-example');
const screenshotPath = process.argv[3];
const types = {
  '.css': 'text/css; charset=utf-8',
  '.data': 'application/octet-stream',
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
};

const server = createServer(async (request, response) => {
  try {
    const pathname = new URL(request.url, 'http://localhost').pathname;
    const file = resolve(root, pathname === '/' ? 'index.html' : `.${pathname}`);
    if (file !== root && !file.startsWith(`${root}${sep}`)) throw new Error('invalid path');
    response.setHeader('Content-Type', types[extname(file)] || 'application/octet-stream');
    response.end(await readFile(file));
  } catch {
    response.statusCode = 404;
    response.end('Not found');
  }
});

await new Promise((accept) => server.listen(0, '127.0.0.1', accept));
const {port} = server.address();
const browser = await chromium.launch({headless: true});
const page = await browser.newPage({viewport: {width: 1100, height: 1000}});
const messages = [];
const errors = [];
page.on('console', (message) => {
  messages.push(message.text());
  if (message.type() === 'error') errors.push(message.text());
});
page.on('pageerror', (error) => errors.push(error.stack || error.message));

try {
  await page.goto(`http://127.0.0.1:${port}/`, {waitUntil: 'networkidle', timeout: 120_000});
  await page.locator('#status[data-love-ready="true"]').waitFor({timeout: 120_000});
  const firstFrame = await page.locator('#canvas').screenshot();
  await page.waitForTimeout(500);
  const laterFrame = await page.locator('#canvas').screenshot();
  assert.notDeepEqual(firstFrame, laterFrame, 'the Lottie frame did not animate');

  await page.locator('#canvas').focus();
  await page.keyboard.press('ArrowRight');
  await page.waitForFunction(() => document.querySelector('#asset-status')?.textContent.includes('Thanksgiving Turkey'));
  if (screenshotPath) await page.screenshot({path: screenshotPath, fullPage: true});

  assert.equal(errors.length, 0, errors.join('\n'));
  assert(messages.some((line) => line.includes('LOVE_THORVG_READY LOVE=11.4.0 OS=Web ABI=2')));
  assert(messages.some((line) => line.includes('LOVE_THORVG_ASSET Relax 151')));
  assert(messages.some((line) => line.includes('LOVE_THORVG_ASSET Thanksgiving Turkey 60')));
  console.log('PASS: LÖVE ran Lua callbacks and animated ThorVG Lottie textures in Chromium.');
} finally {
  await browser.close();
  await new Promise((accept) => server.close(accept));
}
