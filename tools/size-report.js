#!/usr/bin/env node
import { promises as fs } from 'fs';
import path from 'node:path';
import { brotliCompressSync, constants as zlibConstants, gzipSync } from 'node:zlib';

const root = path.resolve(process.argv[2] ?? path.join(process.cwd(), 'dist'));

async function walk(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walk(fullPath));
    } else if (entry.isFile()) {
      files.push(fullPath);
    }
  }
  return files;
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  const units = ['KB', 'MB', 'GB'];
  let size = bytes;
  let unitIndex = -1;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  return `${size.toFixed(2)} ${units[unitIndex]}`;
}

async function main() {
  const files = await walk(root);
  files.sort();

  const rows = [];
  for (const file of files) {
    const buffer = await fs.readFile(file);
    const gzipSize = gzipSync(buffer).length;
    const brotliSize = brotliCompressSync(buffer, {
      params: {
        [zlibConstants.BROTLI_PARAM_QUALITY]: 11,
      },
    }).length;
    rows.push({
      file: path.relative(root, file).replace(/\\/g, '/'),
      size: buffer.length,
      gzip: gzipSize,
      brotli: brotliSize,
    });
  }

  const header = ['File', 'Size', 'gzip', 'brotli'];
  const widths = header.map(h => h.length);
  for (const row of rows) {
    widths[0] = Math.max(widths[0], row.file.length);
    widths[1] = Math.max(widths[1], formatSize(row.size).length);
    widths[2] = Math.max(widths[2], formatSize(row.gzip).length);
    widths[3] = Math.max(widths[3], formatSize(row.brotli).length);
  }

  const pad = (value, width) => value.padEnd(width, ' ');

  console.log(`${pad(header[0], widths[0])}  ${pad(header[1], widths[1])}  ${pad(header[2], widths[2])}  ${pad(header[3], widths[3])}`);
  console.log(`${'-'.repeat(widths[0])}  ${'-'.repeat(widths[1])}  ${'-'.repeat(widths[2])}  ${'-'.repeat(widths[3])}`);
  for (const row of rows) {
    console.log(`${pad(row.file, widths[0])}  ${pad(formatSize(row.size), widths[1])}  ${pad(formatSize(row.gzip), widths[2])}  ${pad(formatSize(row.brotli), widths[3])}`);
  }
}

main().catch(error => {
  console.error(`[size-report] ${error.message}`);
  process.exit(1);
});
