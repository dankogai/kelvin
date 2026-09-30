#!/bin/sh
# Kelvin test runner.
#
#   tests/run/*.k    must compile, exit 0, and print the lines given by
#                    `// out: ...` comments (in order).
#   tests/trap/*.k   must compile, then trap at runtime (exit 134) with a
#                    message containing the `// trap: ...` text.
#   tests/error/*.k  must be rejected by the compiler with a message
#                    containing the `// error: ...` text.

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
    [ -f "$tmp/log" ] && sed 's/^/    /' "$tmp/log" | head -20
}

for f in tests/run/*.k; do
    [ -e "$f" ] || continue
    sed -n 's|^[[:space:]]*// out: \{0,1\}||p' "$f" > "$tmp/expected"
    if ! "$KELVINC" -o "$tmp/prog" "$f" > "$tmp/log" 2>&1; then
        bad "$f" "does not compile"
        continue
    fi
    if ! "$tmp/prog" > "$tmp/actual" 2> "$tmp/log"; then
        bad "$f" "exited with status $?"
        continue
    fi
    if cmp -s "$tmp/expected" "$tmp/actual"; then
        ok
    else
        diff "$tmp/expected" "$tmp/actual" > "$tmp/log"
        bad "$f" "output differs (expected < > actual)"
    fi
done

for f in tests/trap/*.k; do
    [ -e "$f" ] || continue
    want=$(sed -n 's|^[[:space:]]*// trap: ||p' "$f" | head -1)
    if ! "$KELVINC" -o "$tmp/prog" "$f" > "$tmp/log" 2>&1; then
        bad "$f" "does not compile"
        continue
    fi
    "$tmp/prog" > /dev/null 2> "$tmp/log"
    status=$?
    if [ "$status" -ne 134 ]; then
        bad "$f" "expected trap (exit 134), got exit $status"
    elif ! grep -qF "kelvin trap: $want" "$tmp/log"; then
        bad "$f" "trap message does not contain '$want'"
    else
        ok
    fi
done

for f in tests/error/*.k; do
    [ -e "$f" ] || continue
    want=$(sed -n 's|^[[:space:]]*// error: ||p' "$f" | head -1)
    if "$KELVINC" --emit-c -o "$tmp/out.c" "$f" > "$tmp/log" 2>&1; then
        rm -f "$tmp/log"
        bad "$f" "compiled, but should have been rejected"
    elif ! grep -qF "error: $want" "$tmp/log"; then
        bad "$f" "error does not contain '$want'"
    else
        ok
    fi
done

rm -f "$tmp/log"
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
