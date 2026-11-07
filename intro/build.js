// Renders kelvin-intro.md to kelvin-intro.pptx, with editable text.
// keynote.applescript makes the .key and the .pdf from it.
const fs = require("fs"), path = require("path");
const pptxgen = require("pptxgenjs");
const { parseDeck } = require("./parse.js");

const THEME = {
    name: "Kelvin",
    headFontFace: "Georgia",
    bodyFontFace: "Arial",
    colors: {
        dk1: "1B1730", lt1: "FFFFFF", dk2: "5B5675", lt2: "F1EFF7",
        accent1: "D9481F", accent2: "1F8FA3", accent3: "F2B84B",
        accent4: "7A68B3", accent5: "3F9A5B", accent6: "C9C4DA",
        hlink: "F2B84B", folHlink: "F2B84B",
    },
};
const CODE_FONT = "Menlo";
const SYNTAX = { plain: "F4F2FA", comment: "9A95B5", keyword: "F2B84B", type: "6FD3E3", string: "8FDC9B", number: "F39B7C" };
const PANEL = "1B1730", PANEL_TITLE = "2B2545";
const W = 13.333, H = 7.5, MX = 0.6, TOP = 1.5, BOTTOM = 6.95;

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE";
pres.title = "Kelvin: C, changed bit by bit";
pres.author = "Dan Kogai";
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
const C = pres.SchemeColor;

function badge(color, fill) {
    return [{ text: { text: "K", options: { shape: pres.ShapeType.ellipse, fill: { color: fill }, x: W - MX - 0.46, y: 0.57, w: 0.46, h: 0.46, margin: 0, align: "center", valign: "middle", bold: true, fontSize: 15, fontFace: THEME.headFontFace, color } } }];
}
pres.defineSlideMaster({
    title: "CONTENT", background: { color: C.background1 },
    objects: [
        ...badge(C.background1, C.accent1),
        { placeholder: { options: { name: "title", type: "title", x: MX, y: 0.4, w: W - 2 * MX - 0.7, h: 0.8, fontFace: THEME.headFontFace, fontSize: 34, bold: true, color: C.text1, align: "left", valign: "middle", margin: 0 }, text: "" } },
    ],
    slideNumber: { x: W - MX - 0.7, y: 7.02, w: 0.7, h: 0.3, fontSize: 11, color: C.text2, align: "right" },
});
pres.defineSlideMaster({
    title: "DARK", background: { color: C.text1 },
    objects: [
        { placeholder: { options: { name: "title", type: "title", x: 0.9, y: 2.0, w: W - 1.8, h: 1.6, fontFace: THEME.headFontFace, fontSize: 60, bold: true, color: C.background1, align: "left", valign: "bottom", margin: 0 }, text: "" } },
    ],
});

// **bold** and `code` of a line, as runs of text
function inline(text, base = {}, code = {}) {
    const runs = [];
    for (const part of text.split(/(\*\*.+?\*\*|`[^`]+`)/)) {
        if (!part) continue;
        if (part.startsWith("**")) {
            for (const r of inline(part.slice(2, -2), { ...base, bold: true }, code)) runs.push(r);
        } else if (part.startsWith("`")) {
            runs.push({ text: part.slice(1, -1), options: { ...base, fontFace: CODE_FONT, ...code } });
        } else runs.push({ text: part, options: { ...base } });
    }
    return runs;
}
const para = (text, opts, base, code) => {
    const runs = inline(text, base, code);
    return runs.length ? runs : [{ text, options: base || {} }];
};

const KEYWORDS = new Set("let var if else for in while return struct union enum extend static async await try switch case break continue as import include const none true false self".split(" "));
const TYPES = /^(u?int(8|16|32|64|128)(_t)?|[iuf](8|16|32|64|128)|cstr|bool|String|Bytes|Array|Result|Task|FILE|Self|double|int|void|char|long|point|money)$/;

// a line of code as colored tokens, as an editor would show it
function tokens(line) {
    const out = [];
    const re = /(\/\/.*$|\/\*.*?\*\/)|("(?:[^"\\]|\\.)*"|`[^`]*`|\$"(?:[^"\\]|\\.)*")|(\b\d[\dA-Za-z_.]*)|(#\w+\s*<[^>]*>(?:\s+as\s+C)?|#\w+)|([A-Za-z_]\w*)|(\s+)|(.)/g;
    for (const m of line.matchAll(re)) {
        if (m[1]) out.push([m[1], SYNTAX.comment]);
        else if (m[2]) out.push([m[2], SYNTAX.string]);
        else if (m[3]) out.push([m[3], SYNTAX.number]);
        else if (m[4]) out.push([m[4], SYNTAX.keyword]);
        else if (m[5]) out.push([m[5], KEYWORDS.has(m[5]) ? SYNTAX.keyword : TYPES.test(m[5]) ? SYNTAX.type : SYNTAX.plain]);
        else out.push([m[0], SYNTAX.plain]);
    }
    return out.length ? out : [[" ", SYNTAX.plain]];
}
function codeRuns(code, fontSize, colored = true) {
    const runs = [];
    const lines = code.split("\n");
    lines.forEach((line, n) => {
        const toks = colored ? tokens(line) : [[line || " ", SYNTAX.plain]];
        toks.forEach(([text, color], k) => {
            runs.push({ text, options: { color, fontFace: CODE_FONT, fontSize, breakLine: k === toks.length - 1 && n < lines.length - 1 } });
        });
    });
    return runs;
}
const CHAR = 0.602, LINE = 1.25;   // Menlo's advance and line height, of its size
// the largest size at which code fits w by h inches, from 18 down to 12
function fitSize(code, w, h) {
    const lines = code.split("\n");
    const longest = Math.max(...lines.map((l) => l.length));
    for (let s = 18; s > 12; s -= 0.5) {
        if ((longest * s * CHAR) / 72 <= w - 0.4 && (lines.length * s * LINE) / 72 <= h - 0.3) return s;
    }
    return 12;
}
// a rounded panel of code, its name above it; gives where it ends
function panel(slide, fence, x, y, w, h, opts = {}) {
    const titled = !!fence.info.title;
    const head = titled ? 0.36 : 0;
    const body = fence.code;
    const size = opts.size || fitSize(body, w, h - head);
    slide.addShape(pres.ShapeType.roundRect, { x, y, w, h, rectRadius: 0.08, fill: { color: PANEL }, line: { color: PANEL }, objectName: `panel ${fence.info.title || fence.lang}` });
    if (titled) {
        slide.addText(fence.info.title, { x: x + 0.2, y: y + 0.06, w: w - 0.4, h: head, margin: 0, fontFace: CODE_FONT, fontSize: 11, color: SYNTAX.comment, isTextBox: true, objectName: `name ${fence.info.title}` });
    }
    slide.addText(codeRuns(body, size, opts.colored !== false), { x: x + 0.2, y: y + head + 0.08, w: w - 0.3, h: h - head - 0.16, margin: 0, valign: titled ? "top" : "middle", wrap: false, lineSpacingMultiple: 1.04, isTextBox: true, objectName: `code ${fence.info.title || fence.lang}` });
    return size;
}
const codeHeight = (code, size, titled) => (code.split("\n").length * size * LINE) / 72 + 0.34 + (titled ? 0.36 : 0);

function lead(slide, text, y = 1.25, w = W - 2 * MX) {
    slide.addText(para(text, null, {}, { color: C.accent1 }), { x: MX, y, w, h: 0.6, margin: 0, fontSize: 19, color: C.text2, valign: "top", isTextBox: true, objectName: "lead" });
}

// each piece of code that kelvinc refuses, beside what it says, from y down
function errorRows(slide, pairs, top) {
    const gap = 0.14, h = (BOTTOM - top - gap * (pairs.length - 1)) / pairs.length, leftW = 3.9;
    pairs.forEach(([code, msg], i) => {
        const y = top + i * (h + gap);
        panel(slide, code, MX, y, leftW, h, { size: 15 });
        slide.addShape(pres.ShapeType.roundRect, { x: MX + leftW + 0.2, y, w: W - 2 * MX - leftW - 0.2, h, rectRadius: 0.08, fill: { color: C.background2 }, line: { color: C.background2 }, objectName: "message card" });
        slide.addText([{ text: "error: ", options: { bold: true, color: C.accent1 } }, { text: msg.code, options: { color: C.text1 } }], { x: MX + leftW + 0.45, y: y + 0.06, w: W - 2 * MX - leftW - 0.7, h: h - 0.12, margin: 0, fontFace: CODE_FONT, fontSize: 15, valign: "middle", isTextBox: true, objectName: "message" });
    });
}

const layouts = {
    title(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        slide.addText(s.paragraphs[0], { x: 0.9, y: 3.75, w: W - 1.8, h: 0.8, margin: 0, fontFace: THEME.headFontFace, italic: true, fontSize: 30, color: C.accent3, isTextBox: true, objectName: "tagline" });
        slide.addText(s.paragraphs[1], { x: 0.9, y: 4.65, w: W - 1.8, h: 0.5, margin: 0, fontSize: 20, color: C.accent6, isTextBox: true, objectName: "subtitle" });
    },
    closing(slide, s) {
        slide.addText(s.title, { placeholder: "title", fontSize: 44 });
        slide.addText(s.paragraphs[0], { x: 0.9, y: 3.85, w: W - 1.8, h: 0.6, margin: 0, fontFace: CODE_FONT, fontSize: 24, color: C.accent3, isTextBox: true, objectName: "link", hyperlink: { url: "https://" + s.paragraphs[0] } });
        slide.addText(s.paragraphs[1], { x: 0.9, y: 4.5, w: W - 1.8, h: 0.4, margin: 0, fontSize: 16, color: C.accent6, isTextBox: true, objectName: "license" });
    },
    flow(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        lead(slide, s.paragraphs[0], 1.35);
        const n = s.bullets.length, gap = 0.4, w = (W - 2 * MX - gap * (n - 1)) / n, y = 2.3, h = 2.9;
        s.bullets.forEach((b, i) => {
            const [, name, what] = b.match(/^\*\*(.+?)\*\*:\s*(.*)$/);
            const x = MX + i * (w + gap);
            const hot = name === "kelvinc";
            slide.addShape(pres.ShapeType.roundRect, { x, y, w, h, rectRadius: 0.1, fill: { color: hot ? C.accent1 : C.background2 }, line: { color: hot ? C.accent1 : C.background2 }, objectName: `step ${name}` });
            slide.addText(name, { x: x + 0.1, y: y + 0.4, w: w - 0.2, h: 0.6, margin: 0, align: "center", fontFace: CODE_FONT, bold: true, fontSize: 18, color: hot ? C.background1 : C.text1, isTextBox: true, objectName: `step name ${name}` });
            slide.addText(para(what, null, {}, { fontSize: 14 }), { x: x + 0.15, y: y + 1.15, w: w - 0.3, h: 1.5, margin: 0, align: "center", valign: "top", fontSize: 16, color: hot ? C.background1 : C.text2, isTextBox: true, objectName: `step text ${name}` });
            if (i < n - 1) slide.addShape(pres.ShapeType.rightArrow, { x: x + w + 0.07, y: y + h / 2 - 0.13, w: gap - 0.14, h: 0.26, fill: { color: C.accent6 }, line: { color: C.accent6 }, objectName: "arrow" });
        });
        slide.addText(s.paragraphs[1], { x: MX, y: 5.75, w: W - 2 * MX, h: 0.6, margin: 0, fontSize: 21, bold: true, color: C.text1, isTextBox: true, objectName: "point" });
    },
    scale(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        // the dialogue, a bubble a turn, each as tall as its words need
        const dx = MX, dw = 6.3, dtop = TOP, dbottom = 6.2, dgap = 0.18;
        const weight = (q) => q.lines.reduce((a, l) => a + Math.ceil(l.length / 46), 0) + q.lines.length * 0.3 + 1;
        const total = s.quotes.reduce((a, q) => a + weight(q), 0), unit = (dbottom - dtop - dgap * (s.quotes.length - 1)) / total;
        let dy = dtop;
        s.quotes.forEach((q) => {
            const h = weight(q) * unit, claude = q.who === "Claude", ink = claude ? C.background1 : C.text1;
            slide.addShape(pres.ShapeType.roundRect, { x: dx, y: dy, w: dw, h, rectRadius: 0.1, fill: { color: claude ? C.text1 : C.background2 }, line: { color: claude ? C.text1 : C.background2 }, objectName: `turn ${q.who}` });
            slide.addText(q.who, { x: dx + 0.25, y: dy + 0.1, w: dw - 0.5, h: 0.3, margin: 0, bold: true, fontSize: 14, color: claude ? C.accent3 : C.accent1, isTextBox: true, objectName: `speaker ${q.who}` });
            const runs = [];
            q.lines.forEach((l, i) => {
                const rs = para(l, null, { color: ink, paraSpaceAfter: 6 }, { color: claude ? C.accent3 : C.accent1, fontSize: 18 });
                rs[rs.length - 1].options.breakLine = i < q.lines.length - 1;
                runs.push(...rs);
            });
            slide.addText(runs, { x: dx + 0.25, y: dy + 0.42, w: dw - 0.5, h: h - 0.5, margin: 0, valign: "top", fontFace: THEME.headFontFace, fontSize: 20, isTextBox: true, objectName: `words ${q.who}` });
            dy += h + dgap;
        });
        slide.addText(s.paragraphs[0], { x: dx, y: 6.33, w: dw, h: 0.4, margin: 0, fontSize: 14, color: C.text2, isTextBox: true, objectName: "source" });
        // two thermometers, side by side, with the same steps
        const top = 1.65, bottom = 6.45, marks = [["100 °C", "373.15 K"], ["75 °C", "348.15 K"], ["50 °C", "323.15 K"], ["25 °C", "298.15 K"], ["0 °C", "273.15 K"]];
        const a = 8.6, b = 10.0, tube = 0.34;
        slide.addShape(pres.ShapeType.roundRect, { x: a, y: top, w: tube, h: bottom - top, rectRadius: 0.17, fill: { color: C.accent1 }, line: { color: C.accent1 }, objectName: "Celsius" });
        slide.addShape(pres.ShapeType.roundRect, { x: b, y: top, w: tube, h: bottom - top, rectRadius: 0.17, fill: { color: C.accent2 }, line: { color: C.accent2 }, objectName: "Kelvin" });
        marks.forEach(([c, k], i) => {
            const y = top + 0.3 + (i * (bottom - top - 0.6)) / (marks.length - 1);
            slide.addShape(pres.ShapeType.line, { x: a + tube, y, w: b - a - tube, h: 0, line: { color: C.accent6, width: 1 }, objectName: "same step" });
            slide.addText(c, { x: a - 1.25, y: y - 0.18, w: 1.15, h: 0.36, margin: 0, align: "right", fontFace: CODE_FONT, fontSize: 15, color: C.text1, isTextBox: true, objectName: "Celsius mark" });
            slide.addText(k, { x: b + tube + 0.1, y: y - 0.18, w: 1.5, h: 0.36, margin: 0, fontFace: CODE_FONT, fontSize: 15, color: C.text1, isTextBox: true, objectName: "Kelvin mark" });
        });
    },
    compare(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        const [l, r, out] = s.fences;
        const said = s.paragraphs[0];
        const gap = 0.4, w = (W - 2 * MX - gap) / 2, y = TOP, bottomAt = out || said ? BOTTOM - 0.95 : BOTTOM;
        const h = bottomAt - y;
        const size = Math.min(fitSize(l.code, w, h - 0.36), fitSize(r.code, w, h - 0.36));
        panel(slide, l, MX, y, w, h, { size });
        panel(slide, r, MX + w + gap, y, w, h, { size });
        if (out) panel(slide, out, MX + w + gap, bottomAt + 0.15, w, BOTTOM - bottomAt - 0.15, { size: 15, colored: false });
        if (said) slide.addText(para(said, null, {}, { color: C.accent1 }), { x: MX, y: bottomAt + 0.15, w: out ? w : W - 2 * MX, h: 0.8, margin: 0, fontSize: 18, color: C.text1, valign: "middle", isTextBox: true, objectName: "point" });
    },
    code(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        const [code, out] = s.fences;
        const leftW = 7.75, gap = 0.35, y = TOP, rightX = MX + leftW + gap, rightW = W - MX - rightX;
        const said = s.paragraphs[0], plain = code.lang === "text";
        const codeH = said ? codeHeight(code.code, 18, true) : BOTTOM - y;
        panel(slide, code, MX, y, leftW, codeH, plain ? { colored: false, size: said ? 18 : undefined } : {});
        if (said) {
            const sy = y + codeH + 0.2;
            slide.addShape(pres.ShapeType.roundRect, { x: MX, y: sy, w: leftW, h: BOTTOM - sy, rectRadius: 0.08, fill: { color: C.background2 }, line: { color: C.background2 }, objectName: "said card" });
            slide.addText(para(said, null, {}, { fontSize: 15, color: C.accent1 }), { x: MX + 0.2, y: sy + 0.06, w: leftW - 0.4, h: BOTTOM - sy - 0.12, margin: 0, valign: "middle", fontSize: 17, color: C.text1, isTextBox: true, objectName: "said" });
        }
        const outLines = out ? out.code.split("\n").length : 0;
        const longest = out ? Math.max(...out.code.split("\n").map((l) => l.length)) : 0;
        const outSize = out ? Math.max(11, Math.min(15, (((rightW - 0.4) * 72) / longest) / CHAR)) : 15;
        const outH = out ? codeHeight(out.code, outSize, true) : 0;
        if (out) panel(slide, out, rightX, BOTTOM - outH, rightW, outH, { size: outSize, colored: false });
        const cardsH = BOTTOM - y - outH - 0.3;
        const n = s.bullets.length, cardGap = 0.18, ch = Math.min(out ? 1.25 : 1.7, (cardsH - cardGap * (n - 1)) / n);
        s.bullets.forEach((b, i) => {
            const cy = y + i * (ch + cardGap);
            slide.addShape(pres.ShapeType.roundRect, { x: rightX, y: cy, w: rightW, h: ch, rectRadius: 0.08, fill: { color: C.background2 }, line: { color: C.background2 }, objectName: "point card" });
            slide.addText(para(b, null, {}, { fontSize: 15, color: C.accent1 }), { x: rightX + 0.2, y: cy + 0.08, w: rightW - 0.4, h: ch - 0.16, margin: 0, fontSize: 16, color: C.text1, valign: "middle", isTextBox: true, objectName: "point" });
        });
    },
    why(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        lead(slide, s.paragraphs[0], 1.25);
        const y = 1.95, leftW = 5.1, gap = 0.3, rightX = MX + leftW + gap, rightW = W - MX - rightX, h = BOTTOM - y;
        const parts = s.bullets.map((b) => b.match(/^\*\*(.+?)\*\*:\s*(.*)$/));
        const against = parts.filter((m) => !/^\d$/.test(m[1])), answers = parts.filter((m) => /^\d$/.test(m[1]));
        slide.addShape(pres.ShapeType.roundRect, { x: MX, y, w: leftW, h, rectRadius: 0.1, fill: { color: C.text1 }, line: { color: C.text1 }, objectName: "the case against" });
        slide.addText(s.paragraphs[1], { x: MX + 0.3, y: y + 0.22, w: leftW - 0.6, h: 0.45, margin: 0, fontFace: THEME.headFontFace, italic: true, fontSize: 20, color: C.accent6, isTextBox: true, objectName: "against heading" });
        const lines = (w) => Math.ceil(w.length / 34) + 1.6, unit = (h - 1.0) / against.reduce((a, m) => a + lines(m[2]), 0);
        let ry = y + 0.85;
        against.forEach(([, when, what]) => {
            const rowH = lines(what) * unit;
            slide.addText(when, { x: MX + 0.3, y: ry, w: leftW - 0.6, h: 0.32, margin: 0, bold: true, fontSize: 15, color: C.accent3, isTextBox: true, objectName: `when ${when}` });
            slide.addText(what, { x: MX + 0.3, y: ry + 0.32, w: leftW - 0.6, h: rowH - 0.4, margin: 0, valign: "top", fontSize: 18, color: C.background1, isTextBox: true, objectName: `against ${when}` });
            ry += rowH;
        });
        slide.addText(s.paragraphs[2], { x: rightX, y: y + 0.02, w: rightW, h: 0.45, margin: 0, fontFace: THEME.headFontFace, italic: true, fontSize: 20, color: C.text1, isTextBox: true, objectName: "answer heading" });
        const cardGap = 0.14, top = y + 0.55, ch = (h - 0.55 - cardGap * (answers.length - 1)) / answers.length;
        answers.forEach(([, num, what], i) => {
            const cy = top + i * (ch + cardGap);
            slide.addShape(pres.ShapeType.roundRect, { x: rightX, y: cy, w: rightW, h: ch, rectRadius: 0.08, fill: { color: C.background2 }, line: { color: C.background2 }, objectName: `answer card ${num}` });
            slide.addText(num, { shape: pres.ShapeType.ellipse, fill: { color: C.accent1 }, x: rightX + 0.18, y: cy + ch / 2 - 0.25, w: 0.5, h: 0.5, margin: 0, align: "center", valign: "middle", bold: true, fontSize: 18, fontFace: THEME.headFontFace, color: C.background1, objectName: `answer number ${num}` });
            slide.addText(para(what, null, {}, {}), { x: rightX + 0.85, y: cy + 0.06, w: rightW - 1.05, h: ch - 0.12, margin: 0, valign: "middle", fontSize: 17, color: C.text1, isTextBox: true, objectName: `answer ${num}` });
        });
    },
    sizes(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        lead(slide, s.paragraphs[0], 1.25);
        const rows = s.table.slice(1), base = Number(rows[0][1]), baseC = Number(rows[0][2]);
        const gap = 0.5, cw = (W - 2 * MX - gap) / 2, nameW = 0.85, numW = 1.3, barH = 0.44, step = 0.6, y0 = 1.95;
        [[1, base], [2, baseC]].forEach(([col, unit], c) => {
            const x0 = MX + c * (cw + gap), most = Math.max(...rows.map((r) => Number(r[col]))), room = cw - nameW - numW;
            slide.addText(s.table[0][col], { x: x0, y: y0, w: cw, h: 0.34, margin: 0, fontSize: 15, color: C.text2, isTextBox: true, objectName: `chart title ${col}` });
            rows.forEach((r, i) => {
                const v = Number(r[col]), by = y0 + 0.42 + i * step, own = i === 0, bw = Math.max(0.05, (v / most) * room);
                slide.addText(r[0], { x: x0, y: by, w: nameW, h: barH, margin: 0, valign: "middle", bold: own, fontSize: 15, color: C.text1, isTextBox: true, objectName: `name ${r[0]}` });
                slide.addShape(pres.ShapeType.rect, { x: x0 + nameW, y: by, w: bw, h: barH, fill: { color: own ? C.accent1 : C.accent6 }, line: { color: own ? C.accent1 : C.accent6 }, objectName: `bar ${r[0]} ${col}` });
                const times = own ? "" : `  ${Math.round(v / unit)}×`;
                slide.addText([{ text: r[col], options: { bold: true, color: C.text1 } }, { text: times, options: { color: C.text2 } }], { x: x0 + nameW + bw + 0.08, y: by, w: numW, h: barH, margin: 0, valign: "middle", fontSize: 14, isTextBox: true, objectName: `value ${r[0]} ${col}` });
            });
        });
        // Kelvin's bytes, in one strip, each part named where it is
        const sy = y0 + 0.42 + rows.length * step + 0.1, parts = s.bullets.map((b) => b.match(/^\*\*(.+?)\*\*:\s*(.*)$/));
        slide.addText(s.paragraphs[1], { x: MX, y: sy, w: W - 2 * MX, h: 0.34, margin: 0, fontSize: 15, color: C.text2, isTextBox: true, objectName: "strip title" });
        const total = parts.reduce((a, m) => a + Number(m[2]), 0), full = W - 2 * MX, seam = 0.03, fills = [C.accent2, C.accent1, C.accent6], inks = [C.background1, C.background1, C.text1];
        let px = MX;
        parts.forEach(([, name, mb], i) => {
            const pw = (Number(mb) / total) * full;
            slide.addText(`${name} ${mb}`, { shape: pres.ShapeType.rect, fill: { color: fills[i] }, line: { color: fills[i] }, x: px, y: sy + 0.38, w: pw - seam, h: 0.68, margin: 0, align: "center", valign: "middle", bold: true, fontSize: 14, color: inks[i], objectName: `part ${name}` });
            px += pw;
        });
        slide.addText(para(s.paragraphs[2], null, {}, { fontSize: 12, color: C.accent1 }), { x: MX, y: sy + 1.14, w: W - 2 * MX - 0.8, h: 0.55, margin: 0, valign: "top", fontSize: 14, color: C.text2, isTextBox: true, objectName: "how it was measured" });
    },
    dollar(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        lead(slide, s.paragraphs[0], 1.25);
        const [head, ...rows] = s.table;
        // the kelvin and text fences are for check.js: the table is what shows
        const badge = 0.5, gap = 0.2, w = (W - 2 * MX - badge - 2 * gap) / 2, right = MX + w + badge + 2 * gap, y0 = 1.8;
        slide.addText(head[0], { x: MX, y: y0, w, h: 0.36, margin: 0, bold: true, fontSize: 16, color: C.text2, isTextBox: true, objectName: "C's own" });
        slide.addText(head[2], { x: right, y: y0, w, h: 0.36, margin: 0, bold: true, fontSize: 16, color: C.accent1, isTextBox: true, objectName: "with a $" });
        const top = y0 + 0.42, rowGap = 0.1, h = 0.8, litW = 2.0;
        rows.forEach(([cLit, cWhat, kLit, kWhat], i) => {
            const y = top + i * (h + rowGap);
            slide.addShape(pres.ShapeType.roundRect, { x: MX, y, w, h, rectRadius: 0.08, fill: { color: C.background2 }, line: { color: C.background2 }, objectName: `C's ${cLit}` });
            slide.addText(cLit, { x: MX + 0.18, y, w: litW - 0.2, h, margin: 0, valign: "middle", fontFace: CODE_FONT, fontSize: 19, color: C.text1, isTextBox: true, objectName: `literal ${cLit}` });
            slide.addText(para(cWhat, null, {}, { fontSize: 13 }), { x: MX + litW, y, w: w - litW - 0.12, h, margin: 0, valign: "middle", fontSize: 14, color: C.text2, isTextBox: true, objectName: `what ${cLit}` });
            slide.addText("$", { shape: pres.ShapeType.ellipse, fill: { color: C.accent1 }, x: MX + w + gap, y: y + (h - badge) / 2, w: badge, h: badge, margin: 0, align: "center", valign: "middle", bold: true, fontSize: 20, fontFace: CODE_FONT, color: C.background1, objectName: "dollar" });
            slide.addShape(pres.ShapeType.roundRect, { x: right, y, w, h, rectRadius: 0.08, fill: { color: C.text1 }, line: { color: C.text1 }, objectName: `Kelvin's ${kLit}` });
            slide.addText([{ text: "$", options: { color: C.accent3, bold: true } }, { text: kLit.slice(1), options: { color: C.background1 } }], { x: right + 0.18, y, w: litW + 0.05, h, margin: 0, valign: "middle", fontFace: CODE_FONT, fontSize: 19, isTextBox: true, objectName: `literal ${kLit}` });
            slide.addText(para(kWhat, null, {}, { fontSize: 13, color: C.accent3 }), { x: right + litW + 0.25, y, w: w - litW - 0.35, h, margin: 0, valign: "middle", fontSize: 14, color: C.background1, isTextBox: true, objectName: `what ${kLit}` });
        });
        const by = top + rows.length * (h + rowGap) + 0.02;
        slide.addText(para(s.paragraphs[1], null, {}, { fontSize: 15, color: C.accent1 }), { x: MX, y: by, w: W - 2 * MX, h: 0.36, margin: 0, fontSize: 16, color: C.text1, isTextBox: true, objectName: "the limit" });
        slide.addText([{ text: s.quote, options: { italic: true, fontFace: THEME.headFontFace, fontSize: 18, color: C.text1 } }, { text: "   Dan, on the day $ arrived", options: { fontSize: 13, color: C.text2 } }], { x: MX, y: by + 0.36, w: W - 2 * MX - 0.8, h: 0.4, margin: 0, valign: "middle", isTextBox: true, objectName: "quote" });
    },
    pointers(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        // c, kelvin and what it prints, which check.js reads; then pairs of an error and its message
        const [l, r, , ...rest] = s.fences;
        const gap = 0.4, w = (W - 2 * MX - gap) / 2, y = TOP, h = 3.5;
        const size = Math.min(fitSize(l.code, w, h - 0.36), fitSize(r.code, w, h - 0.36));
        panel(slide, l, MX, y, w, h, { size });
        panel(slide, r, MX + w + gap, y, w, h, { size });
        const pairs = [];
        for (let i = 0; i + 1 < rest.length; i += 2) pairs.push([rest[i], rest[i + 1]]);
        errorRows(slide, pairs, y + h + 0.15);
    },
    errors(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        const pairs = [];
        for (let i = 0; i + 1 < s.fences.length; i += 2) pairs.push([s.fences[i], s.fences[i + 1]]);
        errorRows(slide, pairs, TOP);
    },
    cards(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        const cols = 3, rows = Math.ceil(s.bullets.length / cols), gap = 0.25, w = (W - 2 * MX - gap * (cols - 1)) / cols, y0 = TOP, h = 1.42;
        s.bullets.forEach((b, i) => {
            const [, name, what] = b.match(/^\*\*(.+?)\*\*:\s*(.*)$/);
            const x = MX + (i % cols) * (w + gap), y = y0 + Math.floor(i / cols) * (h + gap);
            const own = name === "Your own";
            slide.addShape(pres.ShapeType.roundRect, { x, y, w, h, rectRadius: 0.08, fill: { color: own ? C.accent1 : C.background2 }, line: { color: own ? C.accent1 : C.background2 }, objectName: `module ${name}` });
            slide.addText(name, { x: x + 0.2, y: y + 0.12, w: w - 0.4, h: 0.42, margin: 0, fontFace: CODE_FONT, bold: true, fontSize: 17, color: own ? C.background1 : C.text1, isTextBox: true, objectName: `module name ${name}` });
            slide.addText(para(what, null, {}, { fontSize: 13 }), { x: x + 0.2, y: y + 0.55, w: w - 0.4, h: 0.7, margin: 0, valign: "top", fontSize: 15, color: own ? C.background1 : C.text2, isTextBox: true, objectName: `module text ${name}` });
        });
        slide.addText(para(s.paragraphs[0], null, {}, { color: C.accent1 }), { x: MX, y: y0 + rows * (h + gap) + 0.02, w: W - 2 * MX - 1, h: 0.4, margin: 0, fontSize: 17, color: C.text1, isTextBox: true, objectName: "point" });
    },
    stats(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        const big = s.bullets.filter((b) => /^\*\*[\d,]+\*\*/.test(b)), docs = s.bullets.filter((b) => !/^\*\*[\d,]+\*\*/.test(b));
        const gap = 0.3, w = (W - 2 * MX - gap * 2) / 3, y = TOP, h = 1.9;
        big.forEach((b, i) => {
            const [, num, what] = b.match(/^\*\*(.+?)\*\*\s*(.*)$/);
            const x = MX + i * (w + gap);
            slide.addShape(pres.ShapeType.roundRect, { x, y, w, h, rectRadius: 0.1, fill: { color: C.background2 }, line: { color: C.background2 }, objectName: `stat ${num}` });
            slide.addText(num, { x: x + 0.2, y: y + 0.12, w: w - 0.4, h: 1.0, margin: 0, fontFace: THEME.headFontFace, bold: true, fontSize: 56, color: C.accent1, isTextBox: true, objectName: `number ${num}` });
            slide.addText(what, { x: x + 0.2, y: y + 1.12, w: w - 0.4, h: 0.68, margin: 0, valign: "top", fontSize: 15, color: C.text2, isTextBox: true, objectName: `label ${num}` });
        });
        const qy = y + h + 0.35, leftW = 7.3;
        slide.addText(s.quote, { x: MX, y: qy, w: leftW, h: 0.7, margin: 0, fontFace: THEME.headFontFace, italic: true, fontSize: 28, color: C.text1, isTextBox: true, objectName: "quote" });
        slide.addText(para(s.paragraphs[0], null, {}, { fontSize: 16, color: C.accent1 }), { x: MX, y: qy + 0.75, w: leftW, h: 1.5, margin: 0, valign: "top", fontSize: 18, color: C.text2, isTextBox: true, objectName: "story" });
        const dx = MX + leftW + 0.4, dw = W - MX - dx, dh = 1.0;
        docs.forEach((b, i) => {
            const dy = qy + i * (dh + 0.2);
            slide.addShape(pres.ShapeType.roundRect, { x: dx, y: dy, w: dw, h: dh, rectRadius: 0.08, fill: { color: C.text1 }, line: { color: C.text1 }, objectName: "record card" });
            slide.addText(para(b, null, { color: C.background1 }, {}), { x: dx + 0.2, y: dy + 0.06, w: dw - 0.4, h: dh - 0.12, margin: 0, valign: "middle", fontSize: 16, color: C.background1, isTextBox: true, objectName: "record" });
        });
    },
    selfhost(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        lead(slide, s.paragraphs[0], 1.3);
        const y = 2.25, leftW = 5.3;
        const rows = s.table.slice(1);
        // shapes, not a chart: Keynote drops the charts pptxgenjs writes
        const values = rows.map((r) => Number(r[1])), top = Math.max(...values);
        slide.addText(s.table[0][1], { x: MX, y, w: leftW, h: 0.35, margin: 0, fontSize: 15, color: C.text2, isTextBox: true, objectName: "chart title" });
        const base = BOTTOM - 0.4, tall = base - (y + 0.85), bw = 0.72, step = leftW / rows.length;
        rows.forEach(([name], i) => {
            const bh = (values[i] / top) * tall, bx = MX + i * step + (step - bw) / 2;
            slide.addShape(pres.ShapeType.rect, { x: bx, y: base - bh, w: bw, h: bh, fill: { color: i === rows.length - 1 ? C.accent1 : C.accent6 }, line: { color: i === rows.length - 1 ? C.accent1 : C.accent6 }, objectName: `bar ${name}` });
            slide.addText(String(values[i]), { x: bx - 0.15, y: base - bh - 0.38, w: bw + 0.3, h: 0.34, margin: 0, align: "center", bold: true, fontSize: 16, color: C.text1, isTextBox: true, objectName: `value ${name}` });
            slide.addText(name, { x: bx - 0.15, y: base + 0.06, w: bw + 0.3, h: 0.32, margin: 0, align: "center", fontSize: 14, color: C.text2, isTextBox: true, objectName: `change ${name}` });
        });
        const x = MX + leftW + 0.45, w = W - MX - x, gap = 0.2, h = (BOTTOM - y - gap * 3) / 4;
        s.bullets.forEach((b, i) => {
            const [, name, what] = b.match(/^\*\*(.+?)\*\*:\s*(.*)$/);
            const cy = y + i * (h + gap), now = i === 0;
            slide.addShape(pres.ShapeType.roundRect, { x, y: cy, w, h, rectRadius: 0.08, fill: { color: now ? C.accent1 : C.background2 }, line: { color: now ? C.accent1 : C.background2 }, objectName: `goal ${name}` });
            slide.addText(name, { x: x + 0.2, y: cy + 0.08, w: 1.35, h: h - 0.16, margin: 0, valign: "middle", bold: true, fontSize: 17, color: now ? C.background1 : C.text1, isTextBox: true, objectName: `goal name ${name}` });
            slide.addText(para(what, null, {}, { fontSize: 15 }), { x: x + 1.6, y: cy + 0.08, w: w - 1.8, h: h - 0.16, margin: 0, valign: "middle", fontSize: 17, color: now ? C.background1 : C.text2, isTextBox: true, objectName: `goal text ${name}` });
        });
    },
    try(slide, s) {
        slide.addText(s.title, { placeholder: "title" });
        const y = TOP, panelH = 2.45, cols = 3, gap = 0.22, w = (W - 2 * MX - gap * (cols - 1)) / cols;
        panel(slide, s.fences[0], MX, y, W - 2 * MX, panelH, { size: 17, colored: false });
        const rows = Math.ceil(s.bullets.length / cols), y0 = y + panelH + gap, h = (BOTTOM - y0 - gap * (rows - 1)) / rows;
        s.bullets.forEach((b, i) => {
            const x = MX + (i % cols) * (w + gap), cy = y0 + Math.floor(i / cols) * (h + gap);
            slide.addShape(pres.ShapeType.roundRect, { x, y: cy, w, h, rectRadius: 0.08, fill: { color: C.background2 }, line: { color: C.background2 }, objectName: "fact card" });
            slide.addText(para(b, null, {}, { fontSize: 14, color: C.accent1 }), { x: x + 0.2, y: cy + 0.05, w: w - 0.4, h: h - 0.1, margin: 0, valign: "middle", fontSize: 16, color: C.text1, isTextBox: true, objectName: "fact" });
        });
    },
};

// the theme's colors, which pptxgenjs cannot write itself; a scheme color in
// an option that takes hex is an error here, as PowerPoint would refuse it
async function applyTheme(file, theme) {
    const JSZip = require(require.resolve("jszip", { paths: [require.resolve("pptxgenjs")] }));
    const zip = await JSZip.loadAsync(fs.readFileSync(file));
    const slots = ["dk1", "lt1", "dk2", "lt2", "accent1", "accent2", "accent3", "accent4", "accent5", "accent6", "hlink", "folHlink"];
    const scheme = `<a:clrScheme name="${theme.name}">` + slots.map((k) => `<a:${k}><a:srgbClr val="${theme.colors[k]}"/></a:${k}>`).join("") + "</a:clrScheme>";
    const part = "ppt/theme/theme1.xml";
    const xml = await zip.file(part).async("string");
    zip.file(part, xml.replace(/<a:clrScheme\b[\s\S]*?<\/a:clrScheme>/, () => scheme).replace(/(<a:(?:theme|fontScheme)\b[^>]*?\bname=")[^"]*"/g, (_, head) => `${head}${theme.name}"`));
    for (const name of Object.keys(zip.files)) {
        if (zip.files[name].dir) { delete zip.files[name]; continue; }
        if (!name.endsWith(".xml")) continue;
        const text = await zip.file(name).async("string");
        const bad = text.match(/<a:srgbClr val="((?![0-9A-Fa-f]{6}")[^"]*)"/);
        if (bad) throw new Error(`${name}: '${bad[1]}' is no hex color`);
    }
    fs.writeFileSync(file, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
}

async function main() {
    const deck = parseDeck(fs.readFileSync(path.join(__dirname, "kelvin-intro.md"), "utf8"));
    for (const s of deck) {
        const dark = s.layout === "title" || s.layout === "closing";
        const slide = pres.addSlide({ masterName: dark ? "DARK" : "CONTENT" });
        if (!layouts[s.layout]) throw new Error(`no layout '${s.layout}' for '${s.title}'`);
        layouts[s.layout](slide, s);
        if (s.notes) slide.addNotes(s.notes);
    }
    const file = path.join(__dirname, "kelvin-intro.pptx");
    await pres.writeFile({ fileName: file });
    await applyTheme(file, THEME);
    console.log(`${deck.length} slides: ${path.basename(file)}`);
}
main().catch((e) => { console.error(e); process.exit(1); });
