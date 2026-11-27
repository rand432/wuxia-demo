
import fs from "node:fs";
import zlib from "node:zlib";

const cryptTable = new Uint32Array(0x500);
{
  let seed = 0x00100001;
  for (let i = 0; i < 0x100; i++) {
    let idx = i;
    for (let j = 0; j < 5; j++) {
      seed = (seed * 125 + 3) % 0x2AAAAB;
      const t1 = (seed & 0xFFFF) << 0x10;
      seed = (seed * 125 + 3) % 0x2AAAAB;
      const t2 = (seed & 0xFFFF);
      cryptTable[idx] = (t1 | t2) >>> 0;
      idx += 0x100;
    }
  }
}

export function hashString(name, hashType) {
  let seed1 = 0x7FED7FED >>> 0;
  let seed2 = 0xEEEEEEEE >>> 0;
  const up = name.toUpperCase();
  for (let i = 0; i < up.length; i++) {
    let ch = up.charCodeAt(i);
    if (ch === 0x2f) ch = 0x5c;
    seed1 = (cryptTable[((hashType << 8) + ch) & 0x7ff] ^ ((seed1 + seed2) >>> 0)) >>> 0;
    seed2 = (ch + seed1 + seed2 + (seed2 << 5) + 3) >>> 0;
  }
  return seed1 >>> 0;
}

export function decryptBlock(buf, key) {
  let seed = 0xEEEEEEEE;
  const n = buf.length >> 2;
  for (let i = 0; i < n; i++) {
    seed = (seed + cryptTable[0x400 + (key & 0xff)]) >>> 0;
    const off = i * 4;
    let val = buf.readUInt32LE(off);
    val = (val ^ ((key + seed) >>> 0)) >>> 0;
    buf.writeUInt32LE(val, off);
    key = ((((~key) << 21) + 0x11111111) | (key >>> 11)) >>> 0;
    seed = (val + seed + (seed << 5) + 3) >>> 0;
  }
  return buf;
}

const F = {
  IMPLODE: 0x00000100, COMPRESS: 0x00000200, ENCRYPTED: 0x00010000,
  FIX_KEY: 0x00020000, SINGLE_UNIT: 0x01000000, DELETE: 0x02000000,
  SECTOR_CRC: 0x04000000, EXISTS: 0x80000000,
};

export class MPQ {
  constructor(path) {
    this.path = path;
    this.fd = fs.openSync(path, "r");
    this.size = fs.fstatSync(this.fd).size;
    const head = Buffer.alloc(4);
    fs.readSync(this.fd, head, 0, 4, 0);
    let off = 0;
    if (head.readUInt32LE(0) !== 0x1a51504d) {
      off = 512;
      fs.readSync(this.fd, head, 0, 4, off);
      if (head.readUInt32LE(0) !== 0x1a51504d) throw new Error("no MPQ header");
    }
    this.base = off;
    const h = Buffer.alloc(40);
    fs.readSync(this.fd, h, 0, Math.min(40, this.size - off), off);
    this.headerSize = h.readUInt32LE(4);
    this.archiveSize = h.readUInt32LE(8);
    this.formatVersion = h.readUInt16LE(12);
    this.sectorShift = h.readUInt16LE(14);
    this.sectorSize = 512 << this.sectorShift;
    this.hashTablePos = h.readUInt32LE(16);
    this.blockTablePos = h.readUInt32LE(20);
    this.hashTableSize = h.readUInt32LE(24);
    this.blockTableSize = h.readUInt32LE(28);
    if (this.formatVersion >= 3 && this.headerSize >= 80) {
      const hh = Buffer.alloc(Math.min(this.headerSize, 208));
      fs.readSync(this.fd, hh, 0, hh.length, off);
      try {
        const ht = hh.readBigUInt64LE(64), bt = hh.readBigUInt64LE(72);
        if (ht > 0n && ht < BigInt(this.size)) this.hashTablePos = Number(ht);
        if (bt > 0n && bt < BigInt(this.size)) this.blockTablePos = Number(bt);
        if (hh.length >= 44) { const hiH = hh.readUInt16LE(44), hiB = hh.readUInt16LE(46); this.hashTablePos += hiH * 0x100000000; this.blockTablePos += hiB * 0x100000000; }
      } catch {}
    }
    this._hashCache = null;
    this._blockCache = null;
  }

  readAt(pos, len) {
    const b = Buffer.alloc(len);
    fs.readSync(this.fd, b, 0, len, pos);
    return b;
  }

  validateHashTable(b) {
    let good = 0;
    for (let i = 0; i * 16 < b.length; i++) {
      const blk = b.readUInt32LE(i * 16 + 12);
      if (blk === 0xffffffff || blk < this.blockTableSize) good++;
    }
    return good / (b.length / 16);
  }

  validateBlockTable(b) {
    let good = 0;
    for (let i = 0; i * 16 < b.length; i++) {
      const fp = b.readUInt32LE(i * 16), cs = b.readUInt32LE(i * 16 + 4), fz = b.readUInt32LE(i * 16 + 8), fl = b.readUInt32LE(i * 16 + 12) >>> 0;
      if ((fl & F.EXISTS) !== 0 && cs <= fz && fp + cs <= this.size) good++;
    }
    return good / (b.length / 16);
  }

  get hashTable() {
    if (this._hashCache) return this._hashCache;
    const n = this.hashTableSize * 16;
    const pos = this.base + this.hashTablePos;
    let b = this.readAt(pos, Math.min(n, this.size - pos));
    let score = this.validateHashTable(b);
    if (score < 0.8) {
      const d = decryptBlock(Buffer.from(b), hashString("(hash table)", 3));
      const ds = this.validateHashTable(d);
      if (ds > score) { b = d; score = ds; }
    }
    this.hashTableEncrypted = score >= 0.8 ? "ok" : "unknown";
    const arr = [];
    for (let i = 0; i < this.hashTableSize; i++) {
      const o = i * 16;
      if (o + 16 > b.length) break;
      arr.push({ hashA: b.readUInt32LE(o), hashB: b.readUInt32LE(o + 4), locale: b.readUInt16LE(o + 8), platform: b.readUInt16LE(o + 10), block: b.readUInt32LE(o + 12) });
    }
    this._hashCache = arr;
    return arr;
  }

  get blockTable() {
    if (this._blockCache) return this._blockCache;
    const n = this.blockTableSize * 16;
    const pos = this.base + this.blockTablePos;
    let b = this.readAt(pos, Math.min(n, this.size - pos));
    let score = this.validateBlockTable(b);
    if (score < 0.8) {
      const d = decryptBlock(Buffer.from(b), hashString("(block table)", 3));
      const ds = this.validateBlockTable(d);
      if (ds > score) { b = d; score = ds; }
    }
    this.blockTableEncrypted = score >= 0.8 ? "ok" : "unknown";
    const arr = [];
    for (let i = 0; i < this.blockTableSize; i++) {
      const o = i * 16;
      if (o + 16 > b.length) break;
      arr.push({ filePos: b.readUInt32LE(o), cSize: b.readUInt32LE(o + 4), fSize: b.readUInt32LE(o + 8), flags: b.readUInt32LE(o + 12) >>> 0 });
    }
    this._blockCache = arr;
    return arr;
  }

  find(name) {
    const ht = this.hashTable;
    if (!ht.length) return -1;
    const hashA = hashString(name, 1), hashB = hashString(name, 2);
    const hashOffset = hashString(name, 0);
    let idx = hashOffset % ht.length;
    for (let probe = 0; probe < ht.length; probe++) {
      const e = ht[(idx + probe) % ht.length];
      if (e.block === 0xffffffff) return -1;
      if (e.hashA === hashA && e.hashB === hashB && e.block < this.blockTableSize) return e.block;
    }
    return -1;
  }

  readFile(name) {
    const bi = this.find(name);
    if (bi < 0) return null;
    const r = this.readBlock(bi, name);
    return r ? r[0] : null;
  }

  readBlock(bi, name) {
    const be = this.blockTable[bi];
    if (!be) return null;
    if ((be.flags & F.EXISTS) === 0 || (be.flags & F.DELETE)) return null;
    if (be.cSize === 0 || be.fSize === 0) return [Buffer.alloc(0), Buffer.alloc(0)];
    const absPos = this.base + be.filePos;
    if (absPos + be.cSize > this.size) return null;
    const raw = this.readAt(absPos, be.cSize);
    let key = 0;
    if ((be.flags & F.ENCRYPTED) && name) {
      key = hashString(name.split("/").join(String.fromCharCode(92)), 3);
      if (be.flags & F.FIX_KEY) key = (((key + be.filePos) ^ be.fSize) >>> 0);
    }
    if (be.flags & F.SINGLE_UNIT) {
      let chunk = key ? decryptBlock(Buffer.from(raw), key) : raw;
      const out = this.decompressSector(chunk, be.fSize);
      return out ? [out.subarray(0, be.fSize), Buffer.alloc(0)] : null;
    }
    const sectorCount = Math.max(1, Math.ceil(be.fSize / this.sectorSize));
    const cands = [];
    if (be.fSize <= this.sectorSize) {
      cands.push(absPos);
      cands.push(-1);
    } else {
      if (this.sectorSize > 512) cands.push(absPos + this.sectorSize - 4 * (sectorCount + 1));
      cands.push(absPos);
      cands.push(-1);
    }
    for (const tablePos of cands) {
      const res = this.extractSectors(raw, be, sectorCount, tablePos, key, absPos);
      if (res) return [res, Buffer.alloc(0)];
    }
    return null;
  }

  extractSectors(raw, be, sectorCount, tablePos, key, absPos) {
    let table = null;
    if (tablePos >= 0) {
      const rel = tablePos - absPos;
      if (rel < 0 || rel + 4 * (sectorCount + 1) > raw.length) return null;
      table = Buffer.from(raw.subarray(rel, rel + 4 * (sectorCount + 1)));
      if (key) table = decryptBlock(table, (((key ^ be.filePos) >>> 0) ^ be.fSize) >>> 0);
    }
    const out = Buffer.alloc(be.fSize);
    let outPos = 0;
    for (let s = 0; s < sectorCount; s++) {
      let start, end;
      if (table) {
        start = table.readUInt32LE(s * 4);
        end = table.readUInt32LE((s + 1) * 4);
      } else {
        start = 0;
        end = raw.length;
      }
      if (end <= start || end > raw.length) return null;
      let chunk = Buffer.from(raw.subarray(start, end));
      const expected = Math.min(this.sectorSize, be.fSize - s * this.sectorSize);
      if (key) chunk = decryptBlock(chunk, ((((key + s) >>> 0) ^ be.fSize) >>> 0));
      const data = this.decompressSector(chunk, expected);
      if (!data) return null;
      const take = Math.min(data.length, be.fSize - outPos);
      data.copy(out, outPos, 0, take);
      outPos += take;
      if (outPos >= be.fSize) break;
    }
    if (outPos !== be.fSize) return null;
    return out;
  }

  decompressSector(data, expected) {
    if (data.length === 0) return Buffer.alloc(0);
    const type = data[0];
    const body = data.subarray(1);
    if (data.length === expected) {
      if (type === 0x02) { try { const r = zlib.inflateSync(body); if (r.length) return r; } catch {} }
      return data;
    }
    try {
      if (type === 0x02) return zlib.inflateSync(body);
      if (type === 0x00) return body;
    } catch {}
    try { return zlib.inflateRawSync(data); } catch {}
    try { return zlib.inflateSync(data); } catch {}
    return null;
  }

  close() { try { fs.closeSync(this.fd); } catch {} }
}

export function decodeText(buf) {
  if (!buf) return "";
  const utf8 = buf.toString("utf8");
  const bad = (utf8.match(/\uFFFD/g) || []).length;
  if (bad === 0) return utf8;
  try {
    const dec = new TextDecoder("gbk", { fatal: false });
    const gbk = dec.decode(buf);
    return gbk.length >= utf8.length ? gbk : utf8;
  } catch { return utf8; }
}

export function parseW3i(buf) {
  if (!buf || buf.length < 24) return null;
  let p = 0;
  const i32 = () => { if (p + 4 > buf.length) throw new Error("eof"); const v = buf.readInt32LE(p); p += 4; return v; };
  const cstr = () => {
    const start = p;
    while (p < buf.length && buf[p] !== 0) p++;
    const s = decodeText(buf.subarray(start, p));
    p++;
    return s;
  };
  try {
    const version = i32();
    if (![18, 25, 28, 31].includes(version)) return null;
    const saveCount = i32();
    const editorVersion = i32();
    if (version >= 28) { i32(); i32(); i32(); i32(); }
    if (version >= 31) { /* extra build/game field on Reforged */ i32(); }
    const name = cstr();
    const author = cstr();
    const description = cstr();
    const players = cstr();
    return { version, saveCount, editorVersion, name, author, description, players };
  } catch { return null; }
}

export function parseWts(buf) {
  const text = decodeText(buf);
  const map = new Map();
  const re = /STRING\s+(\d+)\s*\r?\n\{\r?\n([\s\S]*?)\r?\n\}/g;
  let m;
  while ((m = re.exec(text))) map.set(m[1], m[2]);
  return map;
}

export function resolveTrigStrings(value, wts) {
  if (!value) return value;
  return value.replace(/TRIGSTR_(\d+)/g, (all, n) => {
    const v = wts && wts.get(String(parseInt(n, 10)));
    return v != null ? v : all;
  });
}
