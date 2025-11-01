import path from 'node:path';
import { demoSignal } from '../../tools/synth.js';

async function loadModuleFactory() {
  const mod = await import(path.resolve('dist/essentia-wasm.module.js'));
  if (typeof mod.default === 'function') {
    return mod.default;
  }
  if (typeof mod.EssentiaWASM === 'function') {
    return mod.EssentiaWASM;
  }
  throw new Error('Unable to locate Essentia WASM factory export.');
}

function generateDemoVector(essentia) {
  const signal = demoSignal({ seconds: 8, sr: 44100 });
  return essentia.arrayToVector(signal);
}

async function main() {
  const moduleFactory = await loadModuleFactory();
  const wasmModule = await moduleFactory({
    locateFile: (file) => path.resolve('dist', file),
  });
  const webBundle = await import(path.resolve('dist/essentia-wasm.web.js'));
  const EssentiaCtor = webBundle.Essentia ?? webBundle.default;
  if (typeof EssentiaCtor !== 'function') {
    throw new Error('Essentia constructor not found in dist/essentia-wasm.web.js');
  }
  const essentia = new EssentiaCtor(wasmModule);

  const signal = generateDemoVector(essentia);

  const rhythm = essentia.RhythmExtractor2013(signal);
  const tonal = essentia.KeyExtractor(signal);

  console.log('=== Essentia.js WASM Node Demo ===');
  console.log(`BPM: ${rhythm.bpm.toFixed(2)} (confidence ${rhythm.confidence.toFixed(2)})`);
  console.log(`Key: ${tonal.key} ${tonal.scale}`);

  essentia.delete();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
