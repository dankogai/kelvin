#!/bin/sh
# tests/docs.sh (#176): every Kelvin block of the documents and the README,
# fenced ```swift for GitHub's colors (#189), or ```kelvin as before
# compiles. A block with `let main(` is a program and compiles as it is. Any
# other block is a fragment: its declarations at the margin, imports, structs,
# enums, unions, extends, aliases and functions, stay at the top level, and
# the rest, statements, is wrapped in a main, in order. A block that is not
# meant to compile, a sketch with `...` or a module there is none of, has the
# line `<!-- fragment -->` right before its fence, which the rendered page
# does not show. KELVINC picks the compiler.
set -u
cd "$(dirname "$0")/.." || exit 1
KELVINC=${KELVINC:-./kelvinc}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kelvin-docs.XXXXXX") || exit 1
case $tmp in /*) ;; *) echo "bad temporary directory" >&2; exit 1 ;; esac
trap '[ -n "${DOCS_KEEP:-}" ] && cp -R "$tmp" "$DOCS_KEEP"; rm -rf "$tmp"' EXIT

pass=0
fail=0
skipped=0
bad() {
    fail=$((fail + 1))
    printf 'FAIL %s: %s\n' "$1" "$2"
    [ -s "$tmp/log" ] && sed 's/^/    /' "$tmp/log" | head -12
}

# the blocks of a file, one .k each, named by the file and the block's number;
# a fragment is rearranged, a program copied; a marked block is written as .skip
extract() {
    awk -v out="$tmp" -v base="$(basename "$1" .md)" '
    function flush(    i, k, line, depth, top, body, name) {
        n++
        name = out "/" base "_" n
        if (skip) { print "" > (name ".skip"); close(name ".skip"); skip = 0; return }
        if (text ~ /let main\(/) { printf "%s", text > (name ".k"); close(name ".k"); return }
        # a fragment: declarations at the margin stay, the rest goes into a main
        k = split(text, line, "\n")
        depth = 0; top = ""; body = ""
        for (i = 1; i <= k; i++) {
            l = line[i]
            if (depth == 0 && (l ~ /^(#import|struct |union |enum |extend |typealias )/ ||
                               l ~ /^(static |extern )?(let|var) [A-Za-z_][A-Za-z_0-9]*(\.[A-Za-z_][A-Za-z_0-9]*)+[(:]/ ||
                               l ~ /^(let|var) [A-Za-z_][A-Za-z_0-9]*\[\]/ ||
                               l ~ /^(static |extern )?let [A-Za-z_][A-Za-z_0-9]*\(/)) {
                top = top l "\n"
                depth = braces(l)
                intop = 1
            } else if (depth > 0 && intop) {
                top = top l "\n"
                depth += braces(l)
            } else {
                intop = 0
                if (l != "") body = body "    " l "\n"; else body = body "\n"
            }
        }
        printf "%slet main():int32 {\n%s    return 0\n}\n", top, body > (name ".k")
        close(name ".k")
    }
    function braces(l,    s, c, d, i, q) {
        d = 0; q = 0
        for (i = 1; i <= length(l); i++) {
            c = substr(l, i, 1)
            if (c == "\"" && substr(l, i - 1, 1) != "\\") q = !q
            if (q) continue
            if (c == "/" && substr(l, i + 1, 1) == "/") break
            if (c == "{") d++
            if (c == "}") d--
        }
        return d
    }
    /^<!-- fragment -->/ { mark = 1; next }
    /^```(swift|kelvin)$/ { inblock = 1; text = ""; skip = mark; mark = 0; next }
    /^```/ && inblock { inblock = 0; flush(); next }
    inblock { text = text $0 "\n"; next }
    { mark = 0 }
    ' "$1"
}

for md in documents/*.md README.md; do
    extract "$md"
done
for k in "$tmp"/*.k; do
    [ -e "$k" ] || continue
    name=$(basename "$k" .k)
    if "$KELVINC" -o "$tmp/prog" "$k" > "$tmp/log" 2>&1; then
        pass=$((pass + 1))
    else
        cp "$k" "$tmp/failed_$name.k"
        bad "$name" "does not compile"
    fi
done
for s in "$tmp"/*.skip; do
    [ -e "$s" ] && skipped=$((skipped + 1))
done
printf '%d passed, %d failed, %d marked fragments (documents)\n' "$pass" "$fail" "$skipped"
[ "$fail" -eq 0 ]
