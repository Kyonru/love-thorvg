const canvas = document.querySelector('#canvas');
const status = document.querySelector('#status');
const assetStatus = document.querySelector('#asset-status');
const loading = document.querySelector('#loading');

var Module = {
  arguments: ['./'],
  canvas,
  print(message) {
    const text = String(message);
    console.log(text);
    if (text.startsWith('LOVE_THORVG_READY')) {
      status.textContent = text.replace('LOVE_THORVG_READY ', 'Live · ');
      status.dataset.loveReady = 'true';
      loading.hidden = true;
      canvas.focus({preventScroll: true});
    } else if (text.startsWith('LOVE_THORVG_ASSET ')) {
      const details = text.replace('LOVE_THORVG_ASSET ', '').split(' ');
      const duration = details.pop();
      const frames = details.pop();
      assetStatus.textContent = `${details.join(' ')} · ${frames} frames · ${Number(duration).toFixed(2)}s`;
    } else if (text.startsWith('LOVE_THORVG_ERROR ')) {
      assetStatus.textContent = text.replace('LOVE_THORVG_ERROR ', 'Render error · ');
      assetStatus.classList.add('error');
    }
  },
  printErr(message) {
    console.error(message);
  },
  setStatus(message) {
    if (message && status.dataset.loveReady !== 'true') status.textContent = message;
  },
};

canvas.addEventListener('pointerdown', () => canvas.focus({preventScroll: true}));

window.addEventListener('load', () => {
  Love(Module).catch((error) => {
    console.error(error);
    loading.hidden = true;
    status.textContent = `Could not start LÖVE: ${error.message}`;
    status.classList.add('error');
  });
});
