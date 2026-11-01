// Static inspection only: never evaluates Lua or contacts the loader service.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function sha256(value) {
    return crypto.createHash('sha256').update(value).digest('hex');
}

function decodePayload(encoded) {
    if (!encoded.startsWith('LPH%')) throw new Error('Missing LPH% header.');
    const words = [];
    let group = '';
    for (const character of encoded.slice(4)) {
        if (character === 'z') {
            if (group.length !== 0) throw new Error('ASCII85 z inside a group.');
            words.push(0);
            continue;
        }
        const digit = character.charCodeAt(0) - 33;
        if (digit < 0 || digit > 84) throw new Error('Invalid ASCII85 digit.');
        group += character;
        if (group.length === 5) {
            let word = 0;
            for (const byte of group) word = word * 85 + byte.charCodeAt(0) - 33;
            if (word > 0xffffffff) throw new Error('ASCII85 word exceeds uint32.');
            words.push(word);
            group = '';
        }
    }
    if (group.length !== 0) throw new Error('Incomplete ASCII85 group.');
    // The source uses buffer.writeu32, so words are little endian.
    const output = Buffer.alloc(words.length * 4);
    words.forEach((word, index) => output.writeUInt32LE(word, index * 4));
    return output;
}

function inspect(inputPath, outputDirectory, referencePath) {
    const input = fs.readFileSync(inputPath);
    const source = input.toString('utf8');
    const matches = [];
    const literals = /\[(=*)\[([\s\S]*?)\]\1\]/g;
    for (const match of source.matchAll(literals)) {
        if (match[2].startsWith('LPH%')) matches.push(match);
    }
    if (matches.length !== 1) {
        throw new Error(`Expected exactly one LPH% long literal, found ${matches.length}.`);
    }
    const match = matches[0];
    const payload = decodePayload(match[2]);
    const normalized = source.replace(/\r\n/g, '\n');
    const report = {
        inputName: path.basename(inputPath),
        inputBytes: input.length,
        inputSha256: sha256(input),
        lfNormalizedSha256: sha256(normalized),
        format: 'LPH% ASCII85; little-endian uint32 words',
        literalOffset: match.index,
        encodedCharacters: match[2].length,
        decodedBytes: payload.length,
        decodedSha256: sha256(payload),
        luaEvaluated: false,
        networkAccessed: false,
        status: 'Packed data extracted; game behavior has not been reconstructed.',
    };
    if (referencePath) {
        const reference = fs.readFileSync(referencePath, 'utf8').replace(/\r\n/g, '\n');
        report.referenceName = path.basename(referencePath);
        report.matchesReferenceAfterNewlineNormalization = normalized === reference;
    }
    const output = path.resolve(outputDirectory);
    fs.mkdirSync(output, { recursive: true });
    const payloadPath = path.join(output, 'payload-le.bin');
    const reportPath = path.join(output, 'inspection.json');
    if ([payloadPath, reportPath].some(target => target.toLowerCase() === path.resolve(inputPath).toLowerCase())) {
        throw new Error('Output would overwrite the input file.');
    }
    fs.writeFileSync(payloadPath, payload);
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
    return report;
}

if (require.main === module) {
    const [input, output, reference] = process.argv.slice(2);
    if (!input || !output) {
        console.error('Usage: node Tools/inspect-barrage-loader.cjs <input.lua> <output-directory> [reference.lua]');
        process.exitCode = 1;
    } else {
        try { console.log(JSON.stringify(inspect(input, output, reference), null, 2)); }
        catch (error) { console.error(error.message); process.exitCode = 1; }
    }
}

module.exports = { decodePayload, inspect };
