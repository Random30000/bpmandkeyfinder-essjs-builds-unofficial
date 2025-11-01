import { expect, test } from 'vitest';
import path from 'node:path';
import { impulseTrain, sine } from '../tools/synth.js';

const distPath = (file) => path.resolve('dist', file);

async function instantiateEssentia() {
  const moduleImport = await import(distPath('essentia-wasm.module.js'));
  const factory = moduleImport.default ?? moduleImport.EssentiaWASM;
  if (typeof factory !== 'function') {
    throw new Error('Unable to locate Essentia WASM factory export');
  }
  const wasmModule = await factory({
    locateFile: (file) => distPath(file),
  });
  const webImport = await import(distPath('essentia-wasm.web.js'));
  const EssentiaCtor = webImport.Essentia ?? webImport.default;
  if (typeof EssentiaCtor !== 'function') {
    throw new Error('Essentia constructor not exported from dist/essentia-wasm.web.js');
  }
  return new EssentiaCtor(wasmModule);
}

function asLength(output) {
  if (!output) {
    return 0;
  }
  if (typeof output.size === 'function') {
    return output.size();
  }
  if (typeof output.length === 'number') {
    return output.length;
  }
  if (typeof output.size === 'number') {
    return output.size;
  }
  if (typeof output.byteLength === 'number' && typeof output.BYTES_PER_ELEMENT === 'number') {
    return output.byteLength / output.BYTES_PER_ELEMENT;
  }
  return 0;
}

test('WASM loads & RhythmExtractor2013 estimates ~120 BPM', async () => {
  const essentia = await instantiateEssentia();
  try {
    const audio = impulseTrain({ bpm: 120, seconds: 12, sr: 44100 });
    const vector = essentia.arrayToVector(audio);
    const rhythm = essentia.RhythmExtractor2013(vector);
    expect(rhythm.bpm).toBeGreaterThan(110);
    expect(rhythm.bpm).toBeLessThan(130);
  } finally {
    if (typeof essentia.delete === 'function') {
      essentia.delete();
    }
  }
});

test('basic DSP chain works (Spectrum over sine)', async () => {
  const essentia = await instantiateEssentia();
  try {
    const signal = sine({ freq: 440, seconds: 1, sr: 44100 });
    const frame = signal.slice(0, 2048);
    const vector = essentia.arrayToVector(frame);
    const windowed = essentia.Windowing('hann')(vector);
    const spectrum = essentia.Spectrum()(windowed);
    expect(asLength(spectrum)).toBeGreaterThan(0);
  } finally {
    if (typeof essentia.delete === 'function') {
      essentia.delete();
    }
  }
});
