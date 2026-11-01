// Fingerprint-pinned offline decoder. No HTTP requests or game VM execution.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const parse = require('./barrage/parse.cjs');
const buildUnpacker = require('./barrage/unpack.cjs');
const decodeConstants = require('./barrage/constants.cjs');
const disassemble = require('./barrage/disassemble.cjs');
const { decodePayload } = require('./inspect-barrage-loader.cjs');

const EXPECTED_SOURCE = '1cf121ef6750c91d826d8266154ed7981aba9da15bbb104abf4e0ad8a8ae4aab';
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');

function decode(inputPath, outputDirectory, luauPath, parserModule = 'luaparse') {
    const input = fs.readFileSync(inputPath);
    const source = input.toString('utf8').replace(/\r\n/g, '\n');
    if (sha256(source) !== EXPECTED_SOURCE) {
        throw new Error('Unknown loader fingerprint. This decoder accepts only the reviewed source.');
    }
    const lp = require(parserModule);
    const parsed = parse(source, lp);
    if (parsed.table.fields.length !== 191) throw new Error('Unexpected decoder table.');
    const encoded = [...source.matchAll(/\[(=*)\[(LPH%[\s\S]*?)\]\1\]/g)];
    if (encoded.length !== 1) throw new Error('Unexpected packed literal count.');
    const packed = decodePayload(encoded[0][2]);
    const start = 69411, length = 200871;
    if (packed.length !== 270284 || ((packed.readUInt32LE(start - 4) ^ 0x46636b55) >>> 0) !== length) {
        throw new Error('Unexpected second-stage frame.');
    }
    const output = path.resolve(outputDirectory);
    fs.mkdirSync(output, { recursive: true });
    const temporary = fs.mkdtempSync(path.join(output, '.unpack-'));
    const script = path.join(temporary, 'data-only.luau');
    let packet;
    try {
        fs.writeFileSync(script, buildUnpacker(parsed));
        // The generated file has its VM constructor removed before compilation.
        const text = execFileSync(path.resolve(luauPath), [script], {
            encoding: 'utf8', timeout: 30000, maxBuffer: 32 * 1024 * 1024,
            windowsHide: true,
        });
        packet = JSON.parse(text);
    } finally {
        if (fs.existsSync(script)) fs.unlinkSync(script);
        fs.rmdirSync(temporary);
    }
    const decoded = decodeConstants(packet);
    const first = disassemble(parsed, decoded.root.First, decoded.tables);
    const second = disassemble(parsed, decoded.root.Second, decoded.tables, decoded.root.Prototypes);
    if (first.prototypes !== 53 || first.instructions !== 10526 || second.prototypes !== 132 || second.instructions !== 29603) {
        throw new Error('Unexpected recovered function layout.');
    }
    if (decoded.strings.length !== 392 || decoded.constantTypes.number !== 2233 || decoded.constantTypes.boolean !== 2) {
        throw new Error('Unexpected decoded constant layout.');
    }
    const knownStrings = new Set(decoded.strings.map(entry => entry.value));
    for (const expected of ['loadstring', 'https://barrage.cc/catalog', 'https://barrage.cc/session/create', '/script/', 'X-Barrage-Session']) {
        if (!knownStrings.has(expected)) throw new Error('Decoded string validation failed: ' + expected);
    }
    const urls = [...knownStrings].filter(value => /^https:\/\//.test(value));
    const ids = new Map(decoded.tables.map((table, index) => [table, index + 1]));
    const serialize = value => value && typeof value === 'object' ? { ref: ids.get(value) } : value;
    const decodedPacket = {
        root: packet.root,
        tables: decoded.tables.map(table => Object.entries(table).map(([key, value]) => [
            /^\d+$/.test(key) ? Number(key) : key, serialize(value),
        ])),
    };
    const writeJson = (name, value) => fs.writeFileSync(path.join(output, name), JSON.stringify(value, null, 2) + '\n');
    writeJson('strings.json', decoded.strings);
    writeJson('function-index.json', second.index);
    fs.writeFileSync(path.join(output, 'functions.txt'), second.output);
    fs.writeFileSync(path.join(output, 'vm-opcodes.txt'), second.opcodes);
    fs.writeFileSync(path.join(output, 'prototypes.json'), JSON.stringify(decodedPacket) + '\n');
    const manifest = {
        sourceSha256: sha256(input), normalizedSourceSha256: EXPECTED_SOURCE,
        packedBytes: packed.length, frameOffset: start, frameBytes: length,
        frameEnd: decoded.root.End, paddingBytes: packed.length - decoded.root.End,
        frameXorBytes: 'e3 36 18 5b 27 4b 6e 3d',
        stringTransform: { multiplier: 201, increment: 179, modulus: 256, characterXor: 71 },
        firstLayer: { functions: first.prototypes, instructions: first.instructions },
        secondLayer: { functions: second.prototypes, instructions: second.instructions, constants: 2627, strings: decoded.strings.length },
        vmExecuted: false, networkAccessed: false,
        urls,
        limitations: 'Instruction listing retains opaque mutation handlers and padding; it is not a runnable replacement or original source.',
    };
    writeJson('manifest.json', manifest);
    return manifest;
}

if (require.main === module) {
    const [input, output, luau, parser] = process.argv.slice(2);
    if (!input || !output || !luau) {
        console.error('Usage: node Tools/decode-barrage-loader.cjs <input.lua> <output-directory> <luau.exe> [luaparse-module]');
        process.exitCode = 1;
    } else {
        try { console.log(JSON.stringify(decode(input, output, luau, parser), null, 2)); }
        catch (error) { console.error(error.message); process.exitCode = 1; }
    }
}

module.exports = { decode };
