export function impulseTrain({ bpm = 120, seconds = 8, sr = 44100 } = {}) {
  const totalSamples = Math.floor(seconds * sr);
  const output = new Float32Array(totalSamples);
  const hop = Math.max(1, Math.round((60 / bpm) * sr));
  for (let i = 0; i < totalSamples; i += hop) {
    output[i] = 1;
  }
  return output;
}

export function sine({ freq = 440, seconds = 2, sr = 44100 } = {}) {
  const totalSamples = Math.floor(seconds * sr);
  const output = new Float32Array(totalSamples);
  const angular = 2 * Math.PI * freq;
  for (let i = 0; i < totalSamples; i += 1) {
    output[i] = Math.sin((angular * i) / sr);
  }
  return output;
}

export function demoSignal({
  bpm = 120,
  freq = 440,
  seconds = 8,
  sr = 44100,
  beatGain = 0.6,
  toneGain = 0.4,
} = {}) {
  const beats = impulseTrain({ bpm, seconds, sr });
  const tone = sine({ freq, seconds, sr });
  const totalSamples = Math.max(beats.length, tone.length);
  const output = new Float32Array(totalSamples);
  for (let i = 0; i < totalSamples; i += 1) {
    const beatSample = i < beats.length ? beats[i] : 0;
    const toneSample = i < tone.length ? tone[i] : 0;
    output[i] = beatGain * beatSample + toneGain * toneSample;
  }
  return output;
}
