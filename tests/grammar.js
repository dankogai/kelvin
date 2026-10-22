// tests/grammar.js (#190): the TextMate grammar of editors/vscode, applied
// by a small tokenizer of the rules VS Code applies (match, begin/end with
// back references, captures, includes): every regular expression compiles,
// every Kelvin file and document example of the repository tokenizes with
// nothing left open at its end, and sample lines get the scopes they should;
// where zip and unzip are, tools/vsix.sh packages it as VS Code installs it (#191)
'use strict';
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const grammar = JSON.parse(fs.readFileSync(path.join(root, 'editors/vscode/syntaxes/kelvin.tmLanguage.json'), 'utf8'));
let failed = 0, passed = 0;
const fail = (what) => { failed++; console.log('FAIL ' + what); };

// every rule's regular expressions, compiled once
const compiled = new Map();
function re(src) {
    if (!compiled.has(src)) compiled.set(src, new RegExp(src, 'dgu'));
    return compiled.get(src);
}
function rulesOf(list, seen = new Set()) {
    const out = [];
    for (const r of list || []) {
        if (r.include && !r.include.startsWith('#') && r.include !== '$self' && r.include !== 'source.kelvin') {
            continue; /* another language's grammar, as source.c in #inline C (#197): VS Code's, not here */
        }
        if (r.include) {
            const key = r.include === '$self' || r.include === 'source.kelvin' ? null : r.include.slice(1);
            const target = key === null ? { patterns: grammar.patterns } : grammar.repository[key];
            if (!target) { fail('no repository entry ' + r.include); continue; }
            if (seen.has(r.include)) continue;
            out.push(...rulesOf(target.patterns && !target.begin && !target.match ? target.patterns : [target], new Set([...seen, r.include]))); /* a rule of begin and end is itself, its patterns inside it */
        } else {
            out.push(r);
        }
    }
    return out;
}
for (const [name, entry] of Object.entries(grammar.repository)) {
    for (const r of [...(entry.begin || entry.match ? [entry] : []), ...rulesOf(entry.patterns || [])]) {
        for (const k of ['match', 'begin', 'end']) {
            if (!r[k] || (k === 'end' && /\\\d/.test(r[k]))) continue;
            try { re(r[k]); } catch (e) { fail(`${name}: ${k} /${r[k]}/ does not compile: ${e.message}`); }
        }
    }
}

// the tokenizer: a stack of open begin/end rules across lines
function tokenize(text) {
    const tokens = [];
    const stack = [];
    const top = () => stack[stack.length - 1];
    for (const line of text.split('\n')) {
        let pos = 0, guard = 0;
        while (pos <= line.length) {
            if (++guard > 10000) { fail('no progress in: ' + line); break; }
            const frame = top();
            const candidates = frame ? rulesOf(frame.rule.patterns) : rulesOf(grammar.patterns);
            let best = null;
            if (frame) {
                const end = re(frame.end);
                end.lastIndex = pos;
                const m = end.exec(line);
                if (m) best = { kind: 'end', m, rule: frame.rule };
            }
            for (const r of candidates) {
                const src = r.match || r.begin;
                if (!src) continue;
                const x = re(src);
                x.lastIndex = pos;
                const m = x.exec(line);
                if (m && (!best || m.index < best.m.index)) best = { kind: r.match ? 'match' : 'begin', m, rule: r };
            }
            if (!best) {
                if (pos < line.length) tokens.push({ text: line.slice(pos), scopes: scopes() });
                break;
            }
            if (best.m.index > pos) tokens.push({ text: line.slice(pos, best.m.index), scopes: scopes() });
            const caps = best.kind === 'begin' ? best.rule.beginCaptures || best.rule.captures
                         : best.kind === 'end' ? best.rule.endCaptures || best.rule.captures : best.rule.captures;
            const outer = best.kind === 'end' ? scopes(true) : [...scopes(), best.rule.name].filter(Boolean);
            pushCaptures(best.m, caps, outer);
            const after = best.m.index + best.m[0].length;
            if (best.kind === 'begin') {
                const end = best.rule.end.replace(/\\(\d)/g, (_, n) => (best.m[+n] || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
                stack.push({ rule: best.rule, end });
            } else if (best.kind === 'end') {
                stack.pop();
            }
            if (after === pos && best.kind === 'match') pos++; /* an empty match moves on */
            else pos = after;
            if (pos >= line.length && best.kind !== 'begin') break;
        }
        if (top() && /^comment\.line/.test(top().rule.name || '')) stack.pop(); /* a line comment ends at the line's end */
    }
    return { tokens, open: stack.map((f) => f.rule.name) };
    function scopes(closing) {
        const out = [];
        stack.forEach((f, i) => {
            if (f.rule.name) out.push(f.rule.name);
            if (f.rule.contentName && !(closing && i === stack.length - 1)) out.push(f.rule.contentName);
        });
        return out;
    }
    function pushCaptures(m, caps, outer) {
        if (!caps) { tokens.push({ text: m[0], scopes: outer }); return; }
        let at = m.index;
        const ends = m.index + m[0].length;
        const groups = Object.keys(caps).map(Number).filter((n) => n > 0 && m.indices[n]).sort((a, b) => m.indices[a][0] - m.indices[b][0]);
        for (const n of groups) {
            const [s, e] = m.indices[n];
            if (s > at) tokens.push({ text: m.input.slice(at, s), scopes: outer });
            if (e > s) tokens.push({ text: m.input.slice(s, e), scopes: [...outer, caps[n].name] });
            at = Math.max(at, e);
        }
        if (caps[0] && !groups.length) { tokens.push({ text: m[0], scopes: [...outer, caps[0].name] }); return; }
        if (ends > at) tokens.push({ text: m.input.slice(at, ends), scopes: outer });
    }
}

// every Kelvin source and document example of the repository
function walk(dir, out) {
    for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, f.name);
        if (f.isDirectory() && !['build', '.git', '.claude', 'node_modules', 'ucd'].includes(f.name)) walk(p, out);
        else if (/\.(k|kh)$/.test(f.name)) out.push(p);
    }
    return out;
}
const sources = walk(root, []);
const blocks = [];
for (const md of [path.join(root, 'README.md'), path.join(root, 'Style.md'), ...fs.readdirSync(path.join(root, 'documents')).map((f) => path.join(root, 'documents', f))]) {
    if (!md.endsWith('.md')) continue;
    const s = fs.readFileSync(md, 'utf8');
    let i = 0;
    for (const m of s.matchAll(/^```(?:swift|kelvin)\n([\s\S]*?)^```/gm)) blocks.push({ name: `${path.basename(md)} block ${++i}`, text: m[1] });
}
for (const f of sources) {
    const r = tokenize(fs.readFileSync(f, 'utf8'));
    /* an error test may leave a literal open on purpose: it is tokenized, its end not checked */
    if (r.open.length && !f.includes(`${path.sep}tests${path.sep}error${path.sep}`))
        fail(`${path.relative(root, f)}: open at its end: ${r.open.join(' > ')}`);
    else passed++;
}
for (const b of blocks) {
    const r = tokenize(b.text);
    if (r.open.length) fail(`${b.name}: open at its end: ${r.open.join(' > ')}`); else passed++;
}

// sample lines: the scope a piece of text gets
const samples = [
    ['let fib(n:int64):int64 { n < 2 ? n : $(n - 2) + $(n - 1) }', [['let', 'storage.type'], ['fib', 'entity.name.function'], ['int64', 'support.type.primitive'], ['$', 'keyword.other.self-call'], ['2', 'constant.numeric']]],
    ['var xs = $[3, 1, 2].sorted { $0 < $1 }', [['var', 'storage.type'], ['xs', 'variable.other.declaration'], ['$', 'keyword.operator.string-maker'], ['sorted', 'entity.name.function.member'], ['$0', 'variable.parameter.anonymous']]],
    ['let re = $/(\\d+)F\\b/g', [['$', 'keyword.operator.string-maker'], ['\\d', 'constant.character.escape'], ['g', 'keyword.other.regexp-flags']]],
    ['println(`n = ${n * 2}`, " ", $"héllo\\n")', [['println', 'support.function'], ['`', 'string.template'], ['n * 2', 'meta.embedded.line'], ['\\n', 'constant.character.escape'], ['$', 'keyword.operator.string-maker']]],
    ['#import <RegExp>', [['#import', 'keyword.control.import'], ['<RegExp>', 'string.quoted.other.module']]],
    ['#import <math.h> as C', [['as', 'keyword.control.import'], ['C', 'support.constant.language']]],
    ['struct point { x: int64; y: int64 }', [['struct', 'storage.type'], ['point', 'entity.name.type']]],
    ['extend point { let norm:float64 { .x * .x } }', [['extend', 'storage.type'], ['point', 'entity.name.type'], ['float64', 'support.type.primitive']]],
    ['let point.norm():float64 { 1.0 }', [['point', 'entity.name.type'], ['norm', 'entity.name.function'], ['1.0', 'constant.numeric']]],
    ['var p:int32^ := &x   // a reference', [[':=', 'keyword.operator.assignment.reference'], ['^', 'keyword.operator.pointer'], ['// a reference', 'comment.line']]],
    ['for i in 0..<n { if i == 3 { break } }', [['for', 'keyword.control'], ['in', 'keyword.control'], ['..<', 'keyword.operator.range'], ['break', 'keyword.control']]],
    ['var v = r ?? 0; let t = self.x as float64', [['??', 'keyword.operator.coalescing'], ['self', 'variable.language'], ['as', 'keyword.operator.word']]],
    ['var d = d0 !! d1; d0 ??= d1; d0 !!= d1', [['!!', 'keyword.operator.coalescing'], ['??=', 'keyword.operator.assignment.compound'], ['!!=', 'keyword.operator.assignment.compound']]],
    ['var b = Bytes([0x89, 0b101, 0o17, 1e9]) /* bytes */', [['Bytes', 'support.type'], ['0x89', 'constant.numeric.hex'], ['0b101', 'constant.numeric.binary'], ['0o17', 'constant.numeric.octal'], ['1e9', 'constant.numeric.decimal'], ['/* bytes */', 'comment.block']]],
    ['let s := """', [['"""', 'string.quoted.triple']]],
    ['if let v = maybe() { return some(v) } else { return none }', [['some', 'support.function.case'], ['none', 'constant.language']]],
    ["let c = 'x'", [["'x'", 'string.quoted.single']]],
    ['let v = $[nan, -inf, Infinity]; nan("x"); Self.inf', [['nan', 'constant.numeric.decimal'], ['inf', 'constant.numeric.decimal'], ['Infinity', 'constant.numeric.decimal']]],
    ['#inline C { static int one(void) { return \'}\' + "{"; } }', [['#inline', 'keyword.control.directive'], ['C', 'support.constant.language'], [' static int one(void) ', 'meta.embedded.block.c'], ["'}'", 'string.quoted.single.c'], ['"{"', 'string.quoted.double.c']]],
    ['let after = 1', [['let', 'storage.type']]],
    ['    #inline C { total += i; }', [['#inline', 'keyword.control.directive'], [' total += i; ', 'meta.embedded.block.c']]],
];
for (const [line, wants] of samples) {
    const { tokens } = tokenize(line);
    for (const [text, scope] of wants) {
        const joined = [];
        let found = false;
        for (let i = 0; i < tokens.length && !found; i++) {
            let acc = '';
            for (let j = i; j < tokens.length && acc.length < text.length; j++) {
                acc += tokens[j].text;
                if (acc === text && tokens.slice(i, j + 1).every((t) => t.scopes.some((s) => s.startsWith(scope)))) found = true;
            }
        }
        if (found) passed++;
        else {
            const near = tokens.filter((t) => t.text.includes(text) || text.includes(t.text)).map((t) => `${JSON.stringify(t.text)}: ${t.scopes.join(' ') || '(none)'}`);
            fail(`${JSON.stringify(text)} in ${JSON.stringify(line)} is not ${scope}; ${near.slice(0, 3).join('; ')}`);
        }
    }
}
// the package of tools/vsix.sh: the manifest of a .vsix and every file of
// editors/vscode under extension/, the version that of package.json
let packaged = 'no zip';
{
    const { spawnSync } = require('child_process');
    const os = require('os');
    const has = (cmd) => spawnSync('sh', ['-c', `command -v ${cmd}`]).status === 0;
    if (has('zip') && has('unzip')) {
        packaged = 'packaged';
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kelvin-grammar-'));
        try {
            const out = path.join(dir, 'k.vsix');
            const made = spawnSync(path.join(root, 'tools/vsix.sh'), [out], { encoding: 'utf8' });
            if (made.status !== 0 || made.stdout.trim() !== out) fail('tools/vsix.sh: ' + (made.stderr || made.stdout));
            else {
                const list = spawnSync('unzip', ['-Z1', out], { encoding: 'utf8' }).stdout.split('\n');
                const ext = path.join(root, 'editors/vscode');
                const want = ['[Content_Types].xml', 'extension.vsixmanifest', 'extension/LICENSE'];
                const walk = (d, rel) => {
                    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
                        if (e.isDirectory()) walk(path.join(d, e.name), rel + e.name + '/');
                        else want.push('extension/' + rel + e.name);
                    }
                };
                walk(ext, '');
                for (const w of want) list.includes(w) ? passed++ : fail(`${w} is not in the .vsix`);
                const manifest = spawnSync('unzip', ['-p', out, 'extension.vsixmanifest'], { encoding: 'utf8' }).stdout;
                const pkg = JSON.parse(fs.readFileSync(path.join(ext, 'package.json'), 'utf8'));
                const id = `Id="${pkg.name}" Version="${pkg.version}" Publisher="${pkg.publisher}"`;
                manifest.includes(id) ? passed++ : fail(`the manifest has no ${id}`);
                manifest.includes(`Value="${pkg.engines.vscode}"`) ? passed++ : fail('the manifest has no engine ' + pkg.engines.vscode);
            }
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
        }
    }
}
console.log(`${passed} passed, ${failed} failed (grammar: ${sources.length} files, ${blocks.length} document examples, ${samples.length} samples, ${packaged})`);
process.exit(failed ? 1 : 0);
