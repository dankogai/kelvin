#!/bin/sh
# Kelvin test runner.
#
#   tests/run/*.k    must compile, exit 0, and print the lines given by
#                    `// out: ...` comments (in order).
#   tests/error/*.k  must fail to build (in kelvinc or in the C compiler),
#                    with output containing the `// error: ...` text.

cd "$(dirname "$0")/.." || exit 1
KELVINC=${KELVINC:-./kelvinc}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kelvin-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

ok() { pass=$((pass + 1)); }
bad() {
    fail=$((fail + 1))
    printf 'FAIL %s: %s\n' "$1" "$2"
    [ -s "$tmp/log" ] && sed 's/^/    /' "$tmp/log" | head -20
}

for f in tests/run/*.k examples/*.k; do
    [ -e "$f" ] || continue
    sed -n 's|^[[:space:]]*// out: \{0,1\}||p' "$f" > "$tmp/expected"
    if ! "$KELVINC" -o "$tmp/prog" "$f" > "$tmp/log" 2>&1; then
        bad "$f" "does not compile"
        continue
    fi
    if [ -s "$tmp/log" ]; then
        bad "$f" "compiles with diagnostics"
        continue
    fi
    if ! "$tmp/prog" > "$tmp/actual" 2> "$tmp/log"; then
        bad "$f" "exited with status $?"
        continue
    fi
    # examples/ carry no expectations; they only have to build and run
    case "$f" in examples/*) ok; continue ;; esac
    if cmp -s "$tmp/expected" "$tmp/actual"; then
        ok
    else
        diff "$tmp/expected" "$tmp/actual" > "$tmp/log"
        bad "$f" "output differs (expected < > actual)"
    fi
done

for f in tests/error/*.k; do
    [ -e "$f" ] || continue
    want=$(sed -n 's|^[[:space:]]*// error: ||p' "$f" | head -1)
    if "$KELVINC" -o "$tmp/prog" "$f" > "$tmp/log" 2>&1; then
        bad "$f" "built, but should have been rejected"
    elif ! grep -qF -- "$want" "$tmp/log"; then
        bad "$f" "error output does not contain '$want'"
    else
        ok
    fi
done

rm -f "$tmp/log"
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
