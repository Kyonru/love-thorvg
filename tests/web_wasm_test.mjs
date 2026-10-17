import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';

const modulePath = process.argv[2];
if (!modulePath) throw new Error('usage: node tests/web_wasm_test.mjs build/love_thorvg_web.js');
const {default: createModule} = await import(pathToFileURL(modulePath));
const wasm = await createModule();
assert.equal(wasm._love_thorvg_abi_version(), 2);

const encoder = new TextEncoder();
function allocate(bytes, nul = false) {
  const data = typeof bytes === 'string' ? encoder.encode(bytes) : bytes;
  const pointer = wasm._malloc(data.length + (nul ? 1 : 0));
  wasm.HEAPU8.set(data, pointer);
  if (nul) wasm.HEAPU8[pointer + data.length] = 0;
  return {pointer, size: data.length};
}

function renderDocument(source, mime, width, height, progress) {
  const data = allocate(source);
  const type = allocate(mime, true);
  const resource = allocate('', true);
  const output = wasm._malloc(4);
  const error = wasm._malloc(512);
  wasm.HEAPU8[error] = 0;
  const result = wasm._love_thorvg_document_create(
    data.pointer, data.size, type.pointer, resource.pointer, 0, output, error, 512);
  const message = wasm.UTF8ToString(error);
  assert.equal(result, 0, message);
  const document = wasm.HEAPU32[output >>> 2];
  const pixels = wasm._malloc(width * height * 4);
  const renderResult = wasm._love_thorvg_document_render(
    document, pixels, width, height, width, progress, error, 512);
  assert.equal(renderResult, 0, wasm.UTF8ToString(error));
  const frame = Uint8Array.from(wasm.HEAPU8.subarray(pixels, pixels + width * height * 4));
  const metadata = {
    duration: wasm._love_thorvg_document_duration(document),
    frames: wasm._love_thorvg_document_total_frames(document),
    width: wasm._love_thorvg_document_intrinsic_width(document),
    height: wasm._love_thorvg_document_intrinsic_height(document),
  };
  wasm._love_thorvg_document_destroy(document);
  for (const value of [pixels, error, output, resource.pointer, type.pointer, data.pointer]) wasm._free(value);
  return {frame, metadata};
}

const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="#ff0000"/></svg>';
const svgResult = renderDocument(svg, 'svg', 8, 8, 0);
assert.deepEqual([...svgResult.frame.slice((4 * 8 + 4) * 4, (4 * 8 + 4) * 4 + 4)], [255, 0, 0, 255]);
assert.deepEqual([svgResult.metadata.width, svgResult.metadata.height], [8, 8]);

const lottie = JSON.stringify({v:'5.7.4',fr:30,ip:0,op:30,w:8,h:8,nm:'proof',ddd:0,assets:[],layers:[{ddd:0,ind:1,ty:4,nm:'box',sr:1,ks:{o:{a:0,k:100},r:{a:0,k:0},p:{a:0,k:[4,4,0]},a:{a:0,k:[0,0,0]},s:{a:0,k:[100,100,100]}},ao:0,shapes:[{ty:'rc',p:{a:0,k:[0,0]},s:{a:0,k:[8,8]},r:{a:0,k:0}},{ty:'fl',c:{a:0,k:[0,0.5,1,1]},o:{a:0,k:100},r:1}],ip:0,op:30,st:0,bm:0}]});
const lottieResult = renderDocument(lottie, 'lottie+json', 8, 8, 0.5);
assert.ok(lottieResult.metadata.duration > 0);
assert.ok(lottieResult.metadata.frames >= 30);
assert.ok(lottieResult.frame.some((value, index) => index % 4 === 3 && value > 0));

function digest(frame) { return crypto.createHash('sha256').update(frame).digest('hex').slice(0, 16); }
console.log(`SVG: 8x8 red center, rgba sha256 ${digest(svgResult.frame)}`);
console.log(`Lottie: ${lottieResult.metadata.frames} frames / ${lottieResult.metadata.duration.toFixed(3)}s, rgba sha256 ${digest(lottieResult.frame)}`);
console.log('PASS: ThorVG decoded and rasterized SVG and Lottie inside WebAssembly.');
