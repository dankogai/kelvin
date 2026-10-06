#!/bin/sh
# Kelvin test runner.
#
#   tests/run/*.k    must compile, exit 0, and print exactly the lines
#   examples/*.k     given by `// out: ...` comments (in order); the C
#                    that kelvinc writes (--emit-c --no-line) must hold
#                    the text of each `// c: ...` comment.
#   tests/project/*.k  must compile, with the flags of a `// cflags: ...`
#                    comment, exit 0 and print the `// out: ...` lines,
#                    built from inside a copy of tests/project, whose
#                    modules/ is ./modules, with libanswer.a built into
#                    it (#46).
#   tests/error/*.k  must fail to build (in kelvinc or in the C compiler),
#                    with output containing the `// error: ...` text.
#   tests/c/*.c      C programs using libkelvin; built against
#                    modules/libkelvin.a and against the shared library,
#                    each must print the `// out: ...` lines.

cd "$(dirname "$0")/.." || exit 1
KELVINC=${KELVINC:-./kelvinc}
# the trap removes $tmp: it must be the directory mktemp made, and
# nothing else, also where TMPDIR is relative or mktemp fails
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kelvin-test.XXXXXX") || exit 1
[ -n "$tmp" ] && [ -d "$tmp" ] || exit 1
case $tmp in
/*) ;;
*) tmp=$(pwd)/$tmp ;; # so that it holds from other directories too
esac
trap 'rm -rf "$tmp"' EXIT
CC=${CC:-cc}

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
    # after `if ! cmd`, $? would be the 0 of the negation: save it first
    "$tmp/prog" > "$tmp/actual" 2> "$tmp/log"
    status=$?
    if [ "$status" -ne 0 ]; then
        bad "$f" "exited with status $status"
        continue
    fi
    if ! cmp -s "$tmp/expected" "$tmp/actual"; then
        diff "$tmp/expected" "$tmp/actual" > "$tmp/log"
        bad "$f" "output differs (expected < > actual)"
        continue
    fi
    if grep -q '^[[:space:]]*// c: ' "$f"; then
        "$KELVINC" --emit-c --no-line "$f" > "$tmp/c" 2> "$tmp/log"
        missing=$(sed -n 's|^[[:space:]]*// c: ||p' "$f" | while IFS= read -r want; do
            grep -qF -- "$want" "$tmp/c" || printf '%s\n' "$want"
        done)
        if [ -n "$missing" ]; then
            printf '%s\n' "$missing" > "$tmp/log"
            bad "$f" "the C lacks (// c:)"
            continue
        fi
    fi
    ok
done

# kelvinc by a path that holds from inside tests/project too
case $KELVINC in
/*) kelvinc_path=$KELVINC ;;
*/*) kelvinc_path=$(pwd)/$KELVINC ;;
*) kelvinc_path=$KELVINC ;;
esac
cp -R tests/project "$tmp/project"
# ar needs a TMPDIR it can write to (macOS's fails where it is empty)
if ! { "$CC" -c -o "$tmp/answer.o" tests/project/answer.c &&
    TMPDIR=$tmp ar rcs "$tmp/project/modules/libanswer.a" "$tmp/answer.o"; } > "$tmp/log" 2>&1; then
    bad tests/project/answer.c "does not build into libanswer.a"
fi
for f in tests/project/*.k; do
    [ -e "$f" ] || continue
    sed -n 's|^[[:space:]]*// out: \{0,1\}||p' "$f" > "$tmp/expected"
    flags=$(sed -n 's|^[[:space:]]*// cflags: ||p' "$f")
    if ! (cd "$tmp/project" && TMPDIR=$tmp KELVIN_CFLAGS="${KELVIN_CFLAGS:+$KELVIN_CFLAGS }$flags" \
        "$kelvinc_path" -o "$tmp/prog" "${f##*/}") > "$tmp/log" 2>&1; then
        bad "$f" "does not compile"
    elif [ -s "$tmp/log" ]; then
        bad "$f" "compiles with diagnostics"
    elif ! "$tmp/prog" > "$tmp/actual" 2> "$tmp/log"; then
        bad "$f" "exits with a failure"
    elif ! cmp -s "$tmp/expected" "$tmp/actual"; then
        diff "$tmp/expected" "$tmp/actual" > "$tmp/log"
        bad "$f" "output differs (expected < > actual)"
    else
        ok
    fi
done

# Kelvin's modules/ as make install lays it out, next to an installed
# kelvinc and through KELVIN_HOME, from a directory without ./modules (#46)
mkdir -p "$tmp/inst/bin" "$tmp/inst/lib/kelvin/modules" "$tmp/away"
cp "$(command -v "$kelvinc_path")" "$tmp/inst/bin/kelvinc"
cp modules/kelvin_prelude.h modules/libkelvin.a modules/*.k "$tmp/inst/lib/kelvin/modules/"
sed -n 's|^[[:space:]]*// out: \{0,1\}||p' examples/complex.k > "$tmp/expected"
for how in installed KELVIN_HOME; do
    if [ "$how" = installed ]; then
        set -- env -u KELVIN_HOME "$tmp/inst/bin/kelvinc"
    else
        set -- env KELVIN_HOME="$tmp/inst" "$kelvinc_path"
    fi
    if ! (cd "$tmp/away" && TMPDIR=$tmp "$@" -v -o "$tmp/prog" "$OLDPWD/examples/complex.k") > "$tmp/log" 2>&1; then
        bad "modules/ ($how)" "does not compile"
    elif ! grep -qF "lib/kelvin/modules/libkelvin.a" "$tmp/log"; then
        bad "modules/ ($how)" "does not link the installed libkelvin.a"
    elif ! "$tmp/prog" > "$tmp/actual" 2> "$tmp/log"; then
        bad "modules/ ($how)" "exits with a failure"
    elif ! cmp -s "$tmp/expected" "$tmp/actual"; then
        diff "$tmp/expected" "$tmp/actual" > "$tmp/log"
        bad "modules/ ($how)" "output differs (expected < > actual)"
    else
        ok
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

for f in tests/c/*.c; do
    [ -e "$f" ] || continue
    sed -n 's|^[[:space:]]*// out: \{0,1\}||p' "$f" > "$tmp/expected"
    for link in static shared; do
        if [ "$link" = static ]; then
            set -- modules/libkelvin.a -lm
        else
            set -- -Lmodules -lkelvin -Wl,-rpath,"$(pwd)/modules" -lm
        fi
        if ! "$CC" -std=c11 -isystem modules -o "$tmp/cprog" "$f" "$@" > "$tmp/log" 2>&1; then
            bad "$f ($link)" "does not build"
            continue
        fi
        "$tmp/cprog" > "$tmp/actual" 2> "$tmp/log"
        status=$?
        if [ "$status" -ne 0 ]; then
            bad "$f ($link)" "exited with status $status"
        elif ! cmp -s "$tmp/expected" "$tmp/actual"; then
            diff "$tmp/expected" "$tmp/actual" > "$tmp/log"
            bad "$f ($link)" "output differs (expected < > actual)"
        else
            ok
        fi
    done
done

rm -f "$tmp/log"
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
