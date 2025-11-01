import Essentia from '../../dist/essentia.js-core.es.js';
import { demoSignal } from '../../tools/synth.js';

const log = document.getElementById('log');
const player = document.getElementById('player');
const SAMPLE_RATE = 44100;

function float32ToWavBlob(samples, sampleRate) {
  const bytesPerSample = 2;
  const blockAlign = bytesPerSample;
  const buffer = new ArrayBuffer(44 + samples.length * bytesPerSample);
  const view = new DataView(buffer);

  const writeString = (offset, text) => {
    for (let i = 0; i < text.length; i += 1) {
      view.setUint8(offset + i, text.charCodeAt(i));
    }
  };

  writeString(0, 'RIFF');
  view.setUint32(4, 36 + samples.length * bytesPerSample, true);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  view.setUint32(16, 16, true); // Subchunk1Size for PCM
  view.setUint16(20, 1, true); // AudioFormat PCM
  view.setUint16(22, 1, true); // NumChannels mono
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * blockAlign, true); // ByteRate
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, 8 * bytesPerSample, true); // BitsPerSample
  writeString(36, 'data');
  view.setUint32(40, samples.length * bytesPerSample, true);

  let offset = 44;
  for (let i = 0; i < samples.length; i += 1) {
    const sample = Math.max(-1, Math.min(1, samples[i]));
    view.setInt16(offset, sample < 0 ? sample * 0x8000 : sample * 0x7fff, true);
    offset += bytesPerSample;
  }

  return new Blob([buffer], { type: 'audio/wav' });
}

async function loadAudioData() {
  const signal = demoSignal({ seconds: 8, sr: SAMPLE_RATE });
  const blobUrl = URL.createObjectURL(float32ToWavBlob(signal, SAMPLE_RATE));
  player.src = blobUrl;
  return signal;
}

async function main() {
  if (typeof EssentiaWASM !== 'function') {
    throw new Error('EssentiaWASM global factory not found. Did you build the WASM artifacts?');
  }

  const module = await EssentiaWASM({
    locateFile: (file) => new URL(`../../dist/${file}`, import.meta.url).href,
  });

  const essentia = new Essentia(module);
  const channelData = await loadAudioData();
  const signal = essentia.arrayToVector(channelData);

  const rhythm = essentia.RhythmExtractor2013(signal);
  const tonal = essentia.KeyExtractor(signal);

  log.textContent = [
    `BPM: ${rhythm.bpm.toFixed(2)}`,
    `Tempo Confidence: ${rhythm.confidence.toFixed(2)}`,
    `Estimated Key: ${tonal.key} ${tonal.scale}`,
  ].join('\n');

  essentia.delete();
}

main().catch((error) => {
  console.error(error);
  log.textContent = `Error: ${error.message}`;
});
