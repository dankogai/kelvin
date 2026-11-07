// Reads kelvin-intro.md into slides. Slides are split by a line of ---, and
// each may have <!-- layout: name --> and <!-- notes: text --> comments.
function parseInfo(rest) {
    const info = {};
    for (const m of rest.matchAll(/(\w+)(?:=(?:"([^"]*)"|(\S+)))?/g)) info[m[1]] = m[2] ?? m[3] ?? "";
    return info;
}

function parseSlide(text) {
    const slide = { layout: "code", title: "", paragraphs: [], bullets: [], fences: [], table: [], quote: "", quotes: [], notes: "" };
    text = text.replace(/<!--\s*layout:\s*(\w+)\s*-->/, (_, l) => ((slide.layout = l), ""));
    text = text.replace(/<!--\s*notes:\s*([\s\S]*?)\s*-->/, (_, n) => ((slide.notes = n.replace(/\s+/g, " ")), ""));
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const l = lines[i];
        const fence = l.match(/^```(\S*)\s*(.*)$/);
        if (fence) {
            const code = [];
            for (i++; i < lines.length && !lines[i].startsWith("```"); i++) code.push(lines[i]);
            slide.fences.push({ lang: fence[1], info: parseInfo(fence[2]), code: code.join("\n") });
        } else if (l.startsWith("# ")) slide.title = l.slice(2).trim();
        else if (l.startsWith("- ")) slide.bullets.push(l.slice(2).trim());
        else if (l.startsWith("> ")) {
            slide.quote = l.slice(2).trim();
            // "> **Who**: words" opens a turn of a dialogue; a line without it goes on
            const turn = slide.quote.match(/^\*\*(\w+)\*\*:\s*(.*)$/);
            if (turn) slide.quotes.push({ who: turn[1], lines: [turn[2]] });
            else if (slide.quotes.length) slide.quotes[slide.quotes.length - 1].lines.push(slide.quote);
        }
        else if (l.startsWith("|")) {
            const cells = l.split("|").slice(1, -1).map((c) => c.trim());
            if (!cells.every((c) => /^-+$/.test(c))) slide.table.push(cells);
        } else if (l.trim()) slide.paragraphs.push(l.trim());
    }
    return slide;
}

function parseDeck(md) {
    return md.split(/^---$/m).map(parseSlide);
}

module.exports = { parseDeck };
