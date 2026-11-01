// Offline, fingerprint-pinned analysis. No Lua code, game APIs or HTTP requests run.
// node Tools/decode-fakeanegg.cjs INPUT OUTPUT [path/to/luaparse]
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const [input, output, parserPath = 'luaparse'] = process.argv.slice(2);
if (!input || !output) throw Error('Usage: node decode-fakeanegg.cjs INPUT OUTPUT [luaparse-module]');
const bytes = fs.readFileSync(input);
const text = bytes.toString('utf8').replace(/\r\n/g, '\n');
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const fingerprint = '3bb85d19824b4e9d7adc373377041f0661e3a7182c2ebe4d0ad1a8c0dc56a70d';
if (sha(text) !== fingerprint) throw Error('Unrecognized source fingerprint; refusing to decode.');
const lp = require(parserPath);

// Normalize Luau literals/compound assignments for the Lua AST parser. Strings
// remain byte strings; decimal escapes avoid UTF-8 corruption in the parser.
function parse(source) {
    const tokens = [];
    for (let i = 0; i < source.length;) {
        const c = source[i];
        if (/\s/.test(c)) { i++; continue; }
        if (c === '-' && source[i + 1] === '-') {
            const m = source.slice(i + 2).match(/^\[(=*)\[/);
            if (m) {
                const end = source.indexOf(']' + m[1] + ']', i + 2 + m[0].length);
                if (end < 0) throw Error('Unterminated comment');
                i = end + 2 + m[1].length;
            } else {
                const end = source.indexOf('\n', i);
                i = end < 0 ? source.length : end + 1;
            }
            continue;
        }
        if (c === '[') {
            const m = source.slice(i).match(/^\[(=*)\[/);
            if (m) {
                const end = source.indexOf(']' + m[1] + ']', i + m[0].length);
                if (end < 0) throw Error('Unterminated long string');
                tokens.push(source.slice(i, end + 2 + m[1].length));
                i = end + 2 + m[1].length;
                continue;
            }
        }
        if (c === '"' || c === "'") {
            const value = [];
            i++;
            while (i < source.length && source[i] !== c) {
                let v = source[i++];
                if (v !== '\\') { value.push(...Buffer.from(v, 'utf8')); continue; }
                v = source[i++];
                const escapes = { a: 7, b: 8, f: 12, n: 10, r: 13, t: 9, v: 11 };
                if (escapes[v] !== undefined) value.push(escapes[v]);
                else if (v === 'x') { value.push(parseInt(source.slice(i, i + 2), 16)); i += 2; }
                else if (v === 'u' && source[i] === '{') {
                    const end = source.indexOf('}', i);
                    value.push(...Buffer.from(String.fromCodePoint(parseInt(source.slice(i + 1, end), 16)), 'utf8'));
                    i = end + 1;
                } else if (v === 'z') { while (/\s/.test(source[i] || '')) i++; }
                else if (/[0-9]/.test(v)) {
                    let digits = v;
                    while (digits.length < 3 && /[0-9]/.test(source[i] || '')) digits += source[i++];
                    value.push(Number(digits));
                } else value.push(...Buffer.from(v, 'utf8'));
            }
            if (i >= source.length) throw Error('Unterminated quoted string');
            i++;
            tokens.push('"' + value.map(v => '\\' + String(v).padStart(3, '0')).join('') + '"');
            continue;
        }
        const number = source.slice(i).match(/^(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|[0-9]+(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?)/);
        if (number) {
            const raw = number[0].replaceAll('_', '');
            tokens.push(String(/^0b/i.test(raw) ? parseInt(raw.slice(2), 2) : Number(raw)));
            i += number[0].length;
            continue;
        }
        const id = source.slice(i).match(/^[A-Za-z_][A-Za-z_0-9]*/);
        if (id) { tokens.push(id[0] === 'continue' ? 'CONTINUE()' : id[0]); i += id[0].length; continue; }
        const op = ['...', '//', '..=', '+=', '-=', '*=', '/=', '%=', '^=', '==', '~=', '<=', '>=', '..', '::'].find(v => source.startsWith(v, i));
        tokens.push(op || c);
        i += (op || c).length;
    }
    for (let i = 1; i < tokens.length; i++) {
        if (!['+=', '-=', '*=', '/=', '%=', '^=', '..='].includes(tokens[i])) continue;
        if (!/^[A-Za-z_][A-Za-z_0-9]*$/.test(tokens[i - 1])) throw Error('Unsupported compound assignment');
        tokens.splice(i, 1, '=', tokens[i - 1], tokens[i].slice(0, -1));
        i += 2;
    }
    const normalized = tokens.join(' ');
    return lp.parse(normalized, { ranges: true, encodingMode: 'pseudo-latin1', luaVersion: '5.3' });
}
function walk(node, callback) {
    if (!node || typeof node !== 'object') return;
    callback(node);
    for (const [key, value] of Object.entries(node)) if (key !== 'range') {
        if (Array.isArray(value)) value.forEach(item => walk(item, callback));
        else if (value && typeof value === 'object') walk(value, callback);
    }
}
const ast = parse(text), tables = [];
walk(ast, node => { if (node.type === 'TableConstructorExpression') tables.push(node); });
const object = tables.find(node => node.fields.length === 61);
const names = tables.find(node => node.fields.length === 58)?.fields.map(field => field.value.value);
if (!object || !names || new Set(names).size !== 58) throw Error('Unexpected field layout');
const methods = Object.create(null);
let index = 0;
for (const field of object.fields) {
    if (field.type === 'TableKeyString') methods[field.key.name] = field.value;
    else methods[names[(100193 * index++ + 2049) % 58]] = field.value;
}

const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~';
function base85(encoded) {
    const remainder = encoded.length % 5;
    const padded = remainder ? encoded + '~'.repeat(5 - remainder) : encoded;
    const result = Buffer.alloc(padded.length / 5 * 4);
    for (let i = 0; i < padded.length; i += 5) {
        let word = 0;
        for (let j = 0; j < 5; j++) {
            const digit = alphabet.indexOf(padded[i + j]);
            if (digit < 0) throw Error('Invalid Base85 digit');
            word = word * 85 + digit;
        }
        result.writeUInt32BE(word >>> 0, i / 5 * 4);
    }
    return result.subarray(0, remainder ? result.length - (5 - remainder) : result.length).toString('latin1');
}
function xor(data, key, reversed) {
    if (!key.length) throw Error('Empty XOR key');
    const result = Buffer.alloc(data.length);
    for (let i = 0; i < data.length; i++) result[i] = data.charCodeAt(i) ^ key.charCodeAt(reversed ? key.length - 1 - i % key.length : i % key.length);
    return result.toString('latin1');
}
const context = Object.assign(Object.create(null), {
    a: (...values) => values.reduce((a, b) => a & b, -1) >>> 0,
    b: (...values) => values.reduce((a, b) => a | b, 0) >>> 0,
    c: (...values) => values.reduce((a, b) => a ^ b, 0) >>> 0,
    d: value => (~value) >>> 0,
    V: base85, R: (data, key) => xor(data, key, false), T: (data, key) => xor(data, key, true),
    ka: Object.create(null), qa: Object.create(null),
});
const functions = new Set(Object.values(context).filter(value => typeof value === 'function'));
const helperNames = new Set(['la', 'ra', 'ma', 'na', 'oa', 'pa', 'sa', 'ta', 'ua', 'va']);
function get(object, key) {
    if (![context, context.ka, context.qa].includes(object) || !Object.hasOwn(object, key)) throw Error('Unknown constant member ' + key);
    return object[key];
}
// Only arithmetic and whitelisted byte/bit operations can be evaluated. This
// interpreter has no general statements, loops, Lua runtime, globals or host APIs.
function evaluate(node, env) {
    switch (node.type) {
        case 'NumericLiteral': case 'StringLiteral': case 'BooleanLiteral': return node.value;
        case 'NilLiteral': return null;
        case 'Identifier':
            if (!Object.hasOwn(env, node.name)) throw Error('Unknown identifier ' + node.name);
            return env[node.name];
        case 'MemberExpression': return get(evaluate(node.base, env), node.identifier.name);
        case 'IndexExpression': return get(evaluate(node.base, env), evaluate(node.index, env));
        case 'UnaryExpression':
            if (node.operator !== '-') throw Error('Unsupported unary operator');
            return -evaluate(node.argument, env);
        case 'BinaryExpression': {
            const left = evaluate(node.left, env), right = evaluate(node.right, env);
            if (node.operator === '+') return left + right;
            if (node.operator === '-') return left - right;
            if (node.operator === '*') return left * right;
            if (node.operator === '/') return left / right;
            if (node.operator === '%') return left - Math.floor(left / right) * right;
            if (node.operator === '^') return left ** right;
            throw Error('Unsupported binary operator ' + node.operator);
        }
        case 'StringCallExpression': case 'CallExpression': {
            const fn = evaluate(node.base, env);
            if (!functions.has(fn)) throw Error('Call outside constant decoder');
            const args = node.type === 'StringCallExpression' ? [node.argument] : node.arguments;
            return fn(...args.map(arg => evaluate(arg, env)));
        }
        default: throw Error('Unsupported constant expression ' + node.type);
    }
}
function decode(call) {
    if (call.base.base.type !== 'Identifier') throw Error('Unexpected helper receiver');
    const args = call.arguments.map(arg => evaluate(arg, { [call.base.base.name]: context }));
    const method = methods[call.base.identifier.name];
    if (method.body.length !== 2 || method.body[0].type !== 'AssignmentStatement' || method.body[1].type !== 'ReturnStatement') throw Error('Unexpected helper body');
    const env = Object.create(null);
    method.parameters.forEach((parameter, i) => { env[parameter.name] = i === 0 ? context : args[i - 1]; });
    const assignment = method.body[0];
    if (assignment.variables.length !== 1 || assignment.init.length !== 1) throw Error('Unexpected constant assignment');
    const target = assignment.variables[0];
    if (target.type !== 'IndexExpression') throw Error('Non-cache assignment');
    const cache = evaluate(target.base, env), key = evaluate(target.index, env);
    if (![context.ka, context.qa].includes(cache) || typeof key !== 'number') throw Error('Write outside constant cache');
    cache[key] = evaluate(assignment.init[0], env);
    if (method.body[1].arguments.length !== 1) throw Error('Unexpected decoder return');
    return evaluate(method.body[1].arguments[0], env);
}
const calls = [];
walk(ast, node => {
    if (node.type === 'CallExpression' && node.base.type === 'MemberExpression' && node.base.indexer === ':' && helperNames.has(node.base.identifier.name)) calls.push(node);
});
const decoded = calls.map((call, index) => {
    const raw = decode(call), kind = typeof raw;
    if (kind !== 'string' && (kind !== 'number' || !Number.isFinite(raw))) throw Error('Unexpected decoder result');
    return { index, kind, value: kind === 'string' ? Buffer.from(raw, 'latin1').toString('utf8') : raw, range: call.range };
});
if (decoded.length !== 805 || decoded.filter(record => record.kind === 'string').length !== 669) throw Error('Incomplete decode');
const values = new Map(decoded.map(record => [record.range[0], record]));
function simplify(node) {
    if (!node || typeof node !== 'object') return node;
    const record = node.type === 'LogicalExpression' && node.operator === 'or' ? values.get(node.right.range?.[0]) : node.type === 'CallExpression' ? values.get(node.range[0]) : null;
    if (record) return { type: record.kind === 'string' ? 'StringLiteral' : 'NumericLiteral', value: record.value };
    return Object.fromEntries(Object.entries(node).map(([key, value]) => [key, key === 'range' ? value : Array.isArray(value) ? value.map(simplify) : simplify(value)]));
}
const readable = Object.fromEntries(Object.entries(methods).map(([name, method]) => [name, simplify(method)]));
function expression(node, depth = 0) {
    const expr = value => expression(value, depth);
    switch (node.type) {
        case 'Identifier': return node.name;
        case 'NumericLiteral': case 'BooleanLiteral': return String(node.value);
        case 'NilLiteral': return 'nil';
        case 'StringLiteral': return JSON.stringify(node.value);
        case 'VarargLiteral': return '...';
        case 'UnaryExpression': return '(' + node.operator + ' ' + expr(node.argument) + ')';
        case 'BinaryExpression': case 'LogicalExpression': return '(' + expr(node.left) + ' ' + node.operator + ' ' + expr(node.right) + ')';
        case 'MemberExpression': return expr(node.base) + node.indexer + node.identifier.name;
        case 'IndexExpression': return expr(node.base) + '[' + expr(node.index) + ']';
        case 'CallExpression': return expr(node.base) + '(' + node.arguments.map(expr).join(', ') + ')';
        case 'StringCallExpression': return expr(node.base) + '(' + expr(node.argument) + ')';
        case 'TableCallExpression': return expr(node.base) + '(' + expr(node.arguments) + ')';
        case 'TableConstructorExpression': return '{' + node.fields.map(field => field.type === 'TableValue' ? expr(field.value) : '[' + (field.type === 'TableKeyString' ? JSON.stringify(field.key.name) : expr(field.key)) + ']=' + expr(field.value)).join(', ') + '}';
        case 'FunctionDeclaration': return 'function' + (node.identifier ? ' ' + expr(node.identifier) : '') + '(' + node.parameters.map(expr).join(', ') + ')\n' + body(node.body, depth + 1) + '\n' + '  '.repeat(depth) + 'end';
        default: throw Error('Unknown display expression ' + node.type);
    }
}
function body(nodes, depth) {
    const pad = '  '.repeat(depth), expr = value => expression(value, depth);
    return nodes.map(node => {
        switch (node.type) {
            case 'LocalStatement': case 'AssignmentStatement': return pad + (node.type === 'LocalStatement' ? 'local ' : '') + node.variables.map(expr).join(', ') + (node.init.length ? ' = ' + node.init.map(expr).join(', ') : '');
            case 'CallStatement': return pad + expr(node.expression);
            case 'ReturnStatement': return pad + 'return' + (node.arguments.length ? ' ' + node.arguments.map(expr).join(', ') : '');
            case 'BreakStatement': return pad + 'break';
            case 'FunctionDeclaration': return pad + (node.isLocal ? 'local ' : '') + expr(node);
            case 'IfStatement': return node.clauses.map((clause, i) => pad + (i === 0 ? 'if ' + expr(clause.condition) + ' then' : clause.condition ? 'elseif ' + expr(clause.condition) + ' then' : 'else') + '\n' + body(clause.body, depth + 1)).join('\n') + '\n' + pad + 'end';
            case 'WhileStatement': return pad + 'while ' + expr(node.condition) + ' do\n' + body(node.body, depth + 1) + '\n' + pad + 'end';
            case 'RepeatStatement': return pad + 'repeat\n' + body(node.body, depth + 1) + '\n' + pad + 'until ' + expr(node.condition);
            case 'ForNumericStatement': return pad + 'for ' + expr(node.variable) + ' = ' + expr(node.start) + ', ' + expr(node.end) + (node.step ? ', ' + expr(node.step) : '') + ' do\n' + body(node.body, depth + 1) + '\n' + pad + 'end';
            case 'ForGenericStatement': return pad + 'for ' + node.variables.map(expr).join(', ') + ' in ' + node.iterators.map(expr).join(', ') + ' do\n' + body(node.body, depth + 1) + '\n' + pad + 'end';
            case 'DoStatement': return pad + 'do\n' + body(node.body, depth + 1) + '\n' + pad + 'end';
            default: throw Error('Unknown display statement ' + node.type);
        }
    }).join('\n');
}
fs.mkdirSync(output, { recursive: true });
const save = (name, value) => fs.writeFileSync(path.join(output, name), JSON.stringify(value, null, 2) + '\n');
save('manifest.json', {
    input: path.basename(input), sourceBytes: bytes.length, sourceSha256: sha(bytes), normalizedSha256: fingerprint,
    obfuscatorLabel: 'MoonVeil 2.1.0', mappedFields: Object.keys(methods).length, constantExpressions: decoded.length,
    stringResults: 669, distinctStrings: new Set(decoded.filter(record => record.kind === 'string').map(record => record.value)).size,
    execution: 'Static AST inspection and restricted constant arithmetic in JavaScript; original Lua not executed.',
    rangeBasis: 'Offsets in the token-normalized parser input, not original source line numbers.',
});
save('constants.json', decoded);
save('strings.json', decoded.filter(record => record.kind === 'string'));
// The AST preserves state machines and closure captures for further inspection;
// it does not claim to recover original source names or formatting.
fs.writeFileSync(path.join(output, 'decoded-methods.json'), JSON.stringify(readable) + '\n');
fs.writeFileSync(path.join(output, 'functions.txt'), 'Inspection listing: decoded constants; original state machines and closure captures remain.\nNot an executable replacement script.\n\n' + Object.entries(readable).map(([name, method]) => 'FIELD ' + name + ' = ' + expression(method)).join('\n\n') + '\n');
console.log('Decoded 61 fields, 805 constant expressions and 669 string results into ' + output);
