// Compiles every code block of the slides with ../kelvinc and compares what
// it prints, or the error it gives, with the block after it.
const fs = require("fs"), os = require("os"), path = require("path");
const { spawnSync } = require("child_process");
const { parseDeck } = require("./parse.js");

const kelvinc = path.resolve(__dirname, "../kelvinc");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "kelvin-intro-"));
let failures = 0, checks = 0;
const run = (cmd, args, env) => {
    const r = spawnSync(cmd, args, { cwd: tmp, encoding: "utf8", env: { ...process.env, ...env } });
    return { ok: r.status === 0, out: r.stdout || "", err: r.stderr || "" };
};
const report = (slide, what, ok, detail) => {
    checks++;
    if (!ok) failures++;
    if (!ok) console.log(`FAIL slide ${slide} ${what}: ${detail}`);
};
const paths = `modules:${path.resolve(__dirname, "../modules")}`;   // the module, and libkelvin it needs
const libs = { DYLD_LIBRARY_PATH: paths, LD_LIBRARY_PATH: paths };
const write = (name, text) => fs.writeFileSync(path.join(tmp, name), text + "\n");

parseDeck(fs.readFileSync(path.join(__dirname, "kelvin-intro.md"), "utf8")).forEach((slide, i) => {
    const n = i + 1, f = slide.fences;
    let emitted = "";
    f.forEach((b, k) => {
        const next = f[k + 1] && f[k + 1].lang === "text" ? f[k + 1] : null;
        if (b.lang === "kelvin-error") {
            // a statement or two in a main, with what they need beside it
            write("e.k", `let take(s:String) { }\nlet main():i32 {\n${b.info.given || ""}\n${b.code}\nreturn 0\n}`);
            const r = run(kelvinc, ["e.k", "-o", "e"]);
            report(n, `error of ${JSON.stringify(b.code)}`, !r.ok && r.err.includes(next.code), r.err.split("\n")[0]);
        } else if (b.lang === "kelvin" && b.info.lib) {
            write(b.info.title, b.code);
            const r = run(kelvinc, ["--lib", b.info.title]);
            report(n, "library", r.ok, r.err);
        } else if (b.lang === "kelvin") {
            write("p.k", b.code);
            const r = run(kelvinc, ["p.k", "-o", "p"]);
            report(n, `compile ${b.info.title}`, r.ok, r.err.split("\n")[0]);
            const e = run(kelvinc, ["--emit-c", "p.k"]);
            emitted = e.out;
            if (r.ok && next) {
                const o = run(path.join(tmp, "p"), []);
                report(n, `output of ${b.info.title}`, o.out.trim() === next.code.trim(), o.out);
            }
        } else if (b.lang === "c" && b.info.emit !== undefined) {
            // each chunk, between blank lines, as kelvinc writes it; lines may wrap
            const flat = (s) => s.split("\n").filter((l) => !l.startsWith("#")).join(" ").replace(/\s+/g, " ");
            const whole = flat(emitted);
            for (const chunk of b.code.split(/\n\s*\n/)) report(n, "emitted C", whole.includes(flat(chunk).trim()), chunk);
        } else if (b.lang === "c" && b.info.link) {
            write("main.c", b.code);
            const c = run("cc", ["main.c", "-Lmodules", `-lk${b.info.link}`, "-o", "m"]);
            report(n, "C links", c.ok, c.err.split("\n")[0]);
            const o = run(path.join(tmp, "m"), [], libs);
            report(n, "C prints", next && o.out.trim() === next.code.trim(), o.out);
        } else if (b.lang === "c") {
            write("c.c", b.code);
            const c = run("cc", ["-std=c11", "-c", "c.c", "-o", "c.o"]);
            report(n, "C compiles", c.ok, c.err.split("\n")[0]);
        }
    });
});
fs.rmSync(tmp, { recursive: true, force: true });
console.log(`${checks - failures} of ${checks} checks pass`);
process.exit(failures ? 1 : 0);
