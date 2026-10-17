import createModule from './love_thorvg_web.js';

const svgCanvas = document.querySelector('#svg-layer');
const lottieCanvas = document.querySelector('#lottie-layer');
const status = document.querySelector('#status');
const playButton = document.querySelector('#play');
const restartButton = document.querySelector('#restart');
const progressInput = document.querySelector('#progress');
const progressOutput = document.querySelector('#progress-output');
const frameReadout = document.querySelector('#frame-readout');

try {
  const wasm = await createModule();
  const encoder = new TextEncoder();

  function allocate(value, nul = false) {
    const bytes = typeof value === 'string' ? encoder.encode(value) : value;
    const pointer = wasm._malloc(bytes.length + (nul ? 1 : 0));
    wasm.HEAPU8.set(bytes, pointer);
    if (nul) wasm.HEAPU8[pointer + bytes.length] = 0;
    return {pointer, size: bytes.length};
  }

  function createDocument(source, mime) {
    const data = allocate(source);
    const type = allocate(mime, true);
    const resource = allocate('', true);
    const output = wasm._malloc(4);
    const error = wasm._malloc(512);
    const result = wasm._love_thorvg_document_create(
      data.pointer, data.size, type.pointer, resource.pointer, 0, output, error, 512);
    for (const pointer of [resource.pointer, type.pointer, data.pointer]) wasm._free(pointer);
    if (result !== 0) throw new Error(wasm.UTF8ToString(error));
    return {
      handle: wasm.HEAPU32[output >>> 2],
      error,
      pixels: wasm._malloc(svgCanvas.width * svgCanvas.height * 4),
      duration: 0,
    };
  }

  function render(document, canvas, progress) {
    const result = wasm._love_thorvg_document_render(
      document.handle, document.pixels, canvas.width, canvas.height, canvas.width,
      progress, document.error, 512);
    if (result !== 0) throw new Error(wasm.UTF8ToString(document.error));
    const rgba = new Uint8ClampedArray(
      wasm.HEAPU8.buffer, document.pixels, canvas.width * canvas.height * 4);
    canvas.getContext('2d').putImageData(new ImageData(rgba, canvas.width, canvas.height), 0, 0);
  }

  const dialSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="560" height="560" viewBox="0 0 560 560">
    <rect width="560" height="560" rx="18" fill="#0d1923"/>
    <g fill="none" stroke="#294453">
      <circle cx="280" cy="280" r="206"/><circle cx="280" cy="280" r="152"/><circle cx="280" cy="280" r="84"/>
      <path d="M280 44V516M44 280H516M113 113L447 447M447 113L113 447" opacity=".55"/>
    </g>
    <g fill="none" stroke="#8fd3c7" stroke-width="3" stroke-linecap="round">
      <path d="M280 74A206 206 0 0 1 472 205"/><path d="M88 355A206 206 0 0 1 182 99"/>
    </g>
    <circle cx="280" cy="280" r="11" fill="#f07867"/>
    <circle cx="280" cy="280" r="24" fill="none" stroke="#f07867" opacity=".35"/>
  </svg>`;

  const orbitLottie = JSON.stringify({v:'5.7.4',fr:60,ip:0,op:180,w:560,h:560,nm:'web-example',ddd:0,assets:[],layers:[
    {ddd:0,ind:1,ty:4,nm:'mint-orbit',sr:1,ks:{o:{a:0,k:100},r:{a:1,k:[{t:0,s:[0]},{t:180,s:[360]}]},p:{a:0,k:[280,280,0]},a:{a:0,k:[0,0,0]},s:{a:0,k:[100,100,100]}},ao:0,shapes:[{ty:'el',p:{a:0,k:[206,0]},s:{a:0,k:[34,34]}},{ty:'fl',c:{a:0,k:[0.56,0.83,0.78,1]},o:{a:0,k:100},r:1}],ip:0,op:180,st:0,bm:0},
    {ddd:0,ind:2,ty:4,nm:'coral-orbit',sr:1,ks:{o:{a:0,k:100},r:{a:1,k:[{t:0,s:[180]},{t:180,s:[-180]}]},p:{a:0,k:[280,280,0]},a:{a:0,k:[0,0,0]},s:{a:0,k:[100,100,100]}},ao:0,shapes:[{ty:'el',p:{a:0,k:[152,0]},s:{a:0,k:[22,22]}},{ty:'fl',c:{a:0,k:[0.94,0.47,0.4,1]},o:{a:0,k:100},r:1}],ip:0,op:180,st:0,bm:0},
    {ddd:0,ind:3,ty:4,nm:'cyan-orbit',sr:1,ks:{o:{a:0,k:100},r:{a:1,k:[{t:0,s:[65]},{t:180,s:[425]}]},p:{a:0,k:[280,280,0]},a:{a:0,k:[0,0,0]},s:{a:1,k:[{t:0,s:[70,70,100]},{t:90,s:[125,125,100]},{t:180,s:[70,70,100]}]}},ao:0,shapes:[{ty:'el',p:{a:0,k:[84,0]},s:{a:0,k:[15,15]}},{ty:'fl',c:{a:0,k:[0.18,0.62,0.7,1]},o:{a:0,k:100},r:1}],ip:0,op:180,st:0,bm:0}
  ]});

  const svg = createDocument(dialSvg, 'svg');
  const lottie = createDocument(orbitLottie, 'lottie+json');
  lottie.duration = wasm._love_thorvg_document_duration(lottie.handle);
  const totalFrames = Math.round(wasm._love_thorvg_document_total_frames(lottie.handle));
  render(svg, svgCanvas, 0);

  let playing = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let progress = 0;
  let previous = performance.now();
  let dragging = false;

  function setProgress(next) {
    progress = Math.max(0, Math.min(1, next));
    progressInput.value = Math.round(progress * 1000);
    progressOutput.value = `${Math.round(progress * 100)}%`;
    frameReadout.textContent = `frame ${String(Math.floor(progress * (totalFrames - 1))).padStart(3, '0')}`;
    render(lottie, lottieCanvas, progress);
  }

  function updateButton() { playButton.textContent = playing ? 'Pause' : 'Play'; }
  playButton.disabled = false;
  restartButton.disabled = false;
  updateButton();
  status.textContent = `Live · ABI ${wasm._love_thorvg_abi_version()} · SVG + ${totalFrames}-frame Lottie`;
  setProgress(0);

  playButton.addEventListener('click', () => { playing = !playing; updateButton(); previous = performance.now(); });
  restartButton.addEventListener('click', () => { setProgress(0); playing = true; updateButton(); previous = performance.now(); });
  progressInput.addEventListener('pointerdown', () => { dragging = true; });
  progressInput.addEventListener('pointerup', () => { dragging = false; previous = performance.now(); });
  progressInput.addEventListener('input', () => setProgress(Number(progressInput.value) / 1000));

  function tick(now) {
    if (playing && !dragging) setProgress((progress + (now - previous) / 1000 / lottie.duration) % 1);
    previous = now;
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
} catch (error) {
  status.textContent = `Could not start: ${error.message}`;
  status.classList.add('error');
  document.querySelector('.pulse').hidden = true;
}
