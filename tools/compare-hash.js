#!/usr/bin/env node
import { promises as fs } from 'node:fs';
import path from 'node:path';

async function readSums(target) {
  let filePath = target;
  const stats = await fs.stat(target).catch(() => null);
  if (!stats) {
    throw new Error(`Path not found: ${target}`);
  }
  if (stats.isDirectory()) {
    filePath = path.join(target, 'SHA256SUMS.txt');
  }
  const content = await fs.readFile(filePath, 'utf8');
  const entries = new Map();
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    const [hash, ...rest] = trimmed.split(/\s+/);
    entries.set(rest.join(' '), hash);
  }
  return entries;
}

async function main() {
  const [first, second] = process.argv.slice(2);
  if (!first || !second) {
    console.error('Usage: compare-hash.js <path-a> <path-b>');
    process.exit(1);
  }

  const [mapA, mapB] = await Promise.all([readSums(first), readSums(second)]);

  const missingInB = [];
  const missingInA = [];
  const mismatched = [];

  for (const [file, hash] of mapA) {
    if (!mapB.has(file)) {
      missingInB.push(file);
    } else if (mapB.get(file) !== hash) {
      mismatched.push({ file, a: hash, b: mapB.get(file) });
    }
  }

  for (const file of mapB.keys()) {
    if (!mapA.has(file)) {
      missingInA.push(file);
    }
  }

  if (!missingInA.length && !missingInB.length && !mismatched.length) {
    console.log('[compare-hash] Hashes match');
    return;
  }

  if (missingInB.length) {
    console.log('[compare-hash] Missing in second:');
    for (const file of missingInB) console.log(`  - ${file}`);
  }
  if (missingInA.length) {
    console.log('[compare-hash] Missing in first:');
    for (const file of missingInA) console.log(`  - ${file}`);
  }
  if (mismatched.length) {
    console.log('[compare-hash] Hash mismatches:');
    for (const { file, a, b } of mismatched) {
      console.log(`  - ${file}`);
      console.log(`      first : ${a}`);
      console.log(`      second: ${b}`);
    }
  }

  process.exit(1);
}

main().catch(error => {
  console.error(`[compare-hash] ${error.message}`);
  process.exit(1);
});
