#!/bin/sh
# The numbers on the "Standing on C keeps Kelvin small" slide. Bytes of every
# tracked file, and of each compiler's own source, read from each project's
# tarball at its default branch; nothing is unpacked. LLVM is in neither
# rust-lang/rust nor swiftlang/swift, so it is not counted for them, and
# Kelvin's C compiler is not counted for Kelvin.
# usage: sh measure.sh    (from anywhere; downloads about 500 MB)
set -eu
cd "$(dirname "$0")/.."

# the bytes of each tracked file of the tree on stdin, as size<TAB>path
listing() { tar tzvf - | awk '$1 !~ /^d/ { p = $0; sub(/^.*[0-9][0-9]:[0-9][0-9] /, "", p); sub(/^[^\/]*\//, "", p); print $5 "\t" p }'; }
sum() { awk -F '\t' -v re="$1" '$2 ~ re { b += $1 } END { printf "%.1f", b / 1000000 }'; }

peer() {   # name repo branch compiler-source-regex
    sha=$(gh api "repos/$2/commits/$3" --jq .sha)
    curl -sL "https://codeload.github.com/$2/tar.gz/$sha" | listing > "$tmp"
    printf '%-7s %8s MB tracked  %8s MB compiler  %s@%.10s\n' "$1" "$(sum . < "$tmp")" "$(sum "$4" < "$tmp")" "$2" "$sha"
}

tmp=$(mktemp "${TMPDIR:-/tmp}/kelvin-measure.XXXXXX")
trap 'rm -f "$tmp"' EXIT

git ls-files -z | xargs -0 wc -c | grep -v ' total$' | awk '{ print $1 "\t" $2 }' > "$tmp"
printf '%-7s %8s MB tracked  %8s MB compiler  HEAD %s\n' Kelvin "$(sum . < "$tmp")" "$(sum '^src/' < "$tmp")" "$(git rev-parse --short HEAD)"
printf '        of which Unicode data, tools/ucd: %s MB\n' "$(sum '^tools/ucd/' < "$tmp")"

peer Go    golang/go       master '^src/cmd/(compile|link|asm)/.*\.go$'
peer Rust  rust-lang/rust  main   '^compiler/.*\.rs$'
peer Swift swiftlang/swift main   '^(lib|include)/.*\.(cpp|h|def|td|swift)$'
