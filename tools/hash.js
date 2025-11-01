#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { promises as fs, constants as fsConstants } from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] ?? path.join(process.cwd(), 'dist'));
const outputFile = path.join(root, 'SHA256SUMS.txt');

async function ensureDirExists(dir) {
  try {
    await fs.access(dir, fsConstants.F_OK);
  } catch (error) {
    throw new Error(`Directory not found: ${dir}`);
  }
}

async function walk(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walk(fullPath));
    } else if (entry.isFile()) {
      if (path.resolve(fullPath) === path.resolve(outputFile)) {
        continue;
      }
      files.push(fullPath);
    }
  }
  return files;
}

async function hashFile(filePath) {
  const hash = createHash('sha256');
  const handle = await fs.open(filePath, 'r');
  try {
    const stream = handle.createReadStream();
    return await new Promise((resolve, reject) => {
      stream.on('data', chunk => hash.update(chunk));
      stream.on('error', reject);
      stream.on('end', () => resolve(hash.digest('hex')));
    });
  } finally {
    await handle.close();
  }
}

(async () => {
  await ensureDirExists(root);
  const files = await walk(root);
  files.sort();

  const lines = [];
  for (const file of files) {
    const rel = path.relative(root, file).replace(/\\/g, '/');
    const digest = await hashFile(file);
    lines.push(`${digest}  ${rel}`);
  }

  await fs.writeFile(outputFile, lines.join('\n') + (lines.length ? '\n' : ''));
  console.log(`[hash] Wrote ${lines.length} entries to ${path.relative(process.cwd(), outputFile)}`);
})();
