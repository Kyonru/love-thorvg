import createModule from './love_thorvg_web.js';

const status = document.querySelector('#status');
const canvas = document.querySelector('#stage');
const context = canvas.getContext('2d');
const wasm = await createModule();
const encode = new TextEncoder();
const alloc = (value, nul = false) => {
  const bytes = encode.encode(value), pointer = wasm._malloc(bytes.length + (nul ? 1 : 0));
  wasm.HEAPU8.set(bytes, pointer);
  if (nul) wasm.HEAPU8[pointer + bytes.length] = 0;
  return [pointer, bytes.length];
};
const animation = JSON.stringify({v:'5.7.4',fr:60,ip:0,op:120,w:320,h:320,nm:'web proof',ddd:0,assets:[],layers:[{ddd:0,ind:1,ty:4,nm:'orbit',sr:1,ks:{o:{a:0,k:100},r:{a:1,k:[{t:0,s:[0]},{t:120,s:[360]}]},p:{a:0,k:[160,160,0]},a:{a:0,k:[0,0,0]},s:{a:0,k:[100,100,100]}},ao:0,shapes:[{ty:'el',p:{a:0,k:[85,0]},s:{a:0,k:[92,92]}},{ty:'fl',c:{a:0,k:[0.2,0.9,0.7,1]},o:{a:0,k:100},r:1}],ip:0,op:120,st:0,bm:0}]});
const [data, size] = alloc(animation), [mime] = alloc('lottie+json', true), [resource] = alloc('', true);
const output = wasm._malloc(4), error = wasm._malloc(512);
const result = wasm._love_thorvg_document_create(data, size, mime, resource, 0, output, error, 512);
if (result !== 0) throw new Error(wasm.UTF8ToString(error));
const documentHandle = wasm.HEAPU32[output >>> 2], pixels = wasm._malloc(canvas.width * canvas.height * 4);
const duration = wasm._love_thorvg_document_duration(documentHandle);
status.textContent = `Live · ABI ${wasm._love_thorvg_abi_version()} · ${duration.toFixed(2)} seconds`;
const started = performance.now();
function draw(now) {
  const progress = ((now - started) / 1000 % duration) / duration;
  const code = wasm._love_thorvg_document_render(documentHandle, pixels, canvas.width, canvas.height, canvas.width, progress, error, 512);
  if (code !== 0) { status.textContent = wasm.UTF8ToString(error); return; }
  const frame = new Uint8ClampedArray(wasm.HEAPU8.buffer, pixels, canvas.width * canvas.height * 4);
  context.putImageData(new ImageData(frame, canvas.width, canvas.height), 0, 0);
  requestAnimationFrame(draw);
}
requestAnimationFrame(draw);
