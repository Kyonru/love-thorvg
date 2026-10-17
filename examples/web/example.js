import createModule from './love_thorvg_web.js';

const svgCanvas = document.querySelector('#svg-layer');
const lottieCanvas = document.querySelector('#lottie-layer');
const status = document.querySelector('#status');
const playButton = document.querySelector('#play');
const restartButton = document.querySelector('#restart');
const progressInput = document.querySelector('#progress');
const progressOutput = document.querySelector('#progress-output');
const frameReadout = document.querySelector('#frame-readout');
const assetSelect = document.querySelector('#asset');
const stage = document.querySelector('#stage');

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
    if (result !== 0) {
      const message = wasm.UTF8ToString(error);
      wasm._free(output);
      wasm._free(error);
      throw new Error(message);
    }
    const handle = wasm.HEAPU32[output >>> 2];
    wasm._free(output);
    return {
      handle,
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

  const backdropSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="560" height="560" viewBox="0 0 560 560">
    <rect width="560" height="560" rx="18" fill="#0d1923"/>
    <rect x="24" y="24" width="512" height="512" rx="10" fill="none" stroke="#294453"/>
    <path d="M24 76V24H76M484 24H536V76M536 484V536H484M76 536H24V484" fill="none" stroke="#8fd3c7" stroke-width="2" opacity=".7"/>
  </svg>`;

  const assetDefinitions = [
    {id: 'relax', label: 'Relax', file: './assets/relax.json'},
    {id: 'turkey', label: 'Thanksgiving Turkey', file: './assets/turkey.json'},
  ];
  const assetSources = await Promise.all(assetDefinitions.map(async (asset) => {
    const response = await fetch(new URL(asset.file, import.meta.url));
    if (!response.ok) throw new Error(`Could not load ${asset.label} (${response.status})`);
    return response.text();
  }));
  const lotties = new Map(assetDefinitions.map((asset, index) => {
    const document = createDocument(assetSources[index], 'lottie+json');
    document.duration = wasm._love_thorvg_document_duration(document.handle);
    document.frames = Math.round(wasm._love_thorvg_document_total_frames(document.handle));
    return [asset.id, {...asset, document}];
  }));

  const svg = createDocument(backdropSvg, 'svg');
  render(svg, svgCanvas, 0);

  let activeAsset = lotties.get(assetSelect.value);
  let lottie = activeAsset.document;
  let totalFrames = lottie.frames;
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
  function updateStatus() {
    status.textContent = `Live · ABI ${wasm._love_thorvg_abi_version()} · ${activeAsset.label} · ${totalFrames}-frame Lottie`;
    stage.setAttribute('aria-label', `${activeAsset.label} Lottie animation rendered by ThorVG WebAssembly`);
  }
  playButton.disabled = false;
  restartButton.disabled = false;
  assetSelect.disabled = false;
  updateButton();
  updateStatus();
  setProgress(0);

  playButton.addEventListener('click', () => { playing = !playing; updateButton(); previous = performance.now(); });
  restartButton.addEventListener('click', () => { setProgress(0); playing = true; updateButton(); previous = performance.now(); });
  progressInput.addEventListener('pointerdown', () => { dragging = true; });
  progressInput.addEventListener('pointerup', () => { dragging = false; previous = performance.now(); });
  progressInput.addEventListener('input', () => setProgress(Number(progressInput.value) / 1000));
  assetSelect.addEventListener('change', () => {
    activeAsset = lotties.get(assetSelect.value);
    lottie = activeAsset.document;
    totalFrames = lottie.frames;
    updateStatus();
    setProgress(0);
    previous = performance.now();
  });

  function tick(now) {
    if (playing && !dragging) setProgress((progress + (now - previous) / 1000 / Math.max(lottie.duration, 0.001)) % 1);
    previous = now;
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
} catch (error) {
  status.textContent = `Could not start: ${error.message}`;
  status.classList.add('error');
  document.querySelector('.pulse').hidden = true;
}
