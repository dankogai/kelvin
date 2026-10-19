#!/bin/sh
# tests/asan.sh (#175): every program of tests/run, with the runtime and the
# modules, compiled with AddressSanitizer and the counting allocator of
# tests/asan/count.c, and run: a test fails where ASan reports an error, the
# program exits with a status it did not expect, or a block is still live
# at exit, which is a leak the ownership rules should have freed. A test
# that expects a status other than 0 (// exit: N), or calls SYS.exit, is run
# for ASan alone, since an exit cuts the frees short; a count below zero is a
# free of what the C library allocated, realpath's result, which the counter
# never saw, and passes. CC picks the compiler, clang or gcc.
set -u
cd "$(dirname "$0")/.." || exit 1
CC=${CC:-cc}
KELVINC=${KELVINC:-./kelvinc}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kelvin-asan.XXXXXX") || exit 1
case $tmp in /*) ;; *) echo "bad temporary directory" >&2; exit 1 ;; esac
trap 'rm -rf "$tmp"' EXIT
# the feature macros io.c and os.c define come after the included stdlib.h here, so they go first;
# the BSDs want none of them (#192)
case $(uname -s) in
FreeBSD | NetBSD | OpenBSD | DragonFly) features= ;;
*) features="-D_XOPEN_SOURCE=700 -D_DEFAULT_SOURCE=1 -D_DARWIN_C_SOURCE=" ;;
esac
flags="-std=c11 -g -O1 -fno-omit-frame-pointer -fsanitize=address -fno-sanitize-recover=all $features \
    -Dmalloc=kv_cnt_malloc -Drealloc=kv_cnt_realloc -Dfree=kv_cnt_free -include stdlib.h -w -Imodules -Iruntime"
export ASAN_OPTIONS=detect_leaks=0:abort_on_error=0

pass=0
fail=0
bad() {
    fail=$((fail + 1))
    printf 'FAIL %s: %s\n' "$1" "$2"
    [ -s "$tmp/log" ] && sed 's/^/    /' "$tmp/log" | head -20
}

# the counting allocator, compiled without the renaming, which would rename its own calls
if ! $CC -std=c11 -g -O1 -fsanitize=address -c -o "$tmp/count.o" tests/asan/count.c > "$tmp/log" 2>&1; then
    bad tests/asan/count.c "does not compile"
    exit 1
fi
# the runtime, every file, and the C of the modules written in Kelvin
objs="$tmp/count.o"
for src in runtime/*.c; do
    o="$tmp/$(basename "$src" .c).o"
    if ! $CC $flags -c -o "$o" "$src" > "$tmp/log" 2>&1; then
        bad "$src" "does not compile with ASan"
        exit 1
    fi
    objs="$objs $o"
done
for mod in modules/*.k; do
    name=$(basename "$mod" .k)
    [ -e "modules/$name.kh" ] || continue  # a module built by make into a library
    if ! "$KELVINC" --lib --emit-c "$mod" > "$tmp/$name.c" 2> "$tmp/log"; then
        bad "$mod" "kelvinc --lib --emit-c failed"
        exit 1
    fi
    if ! $CC $flags -c -o "$tmp/mod_$name.o" "$tmp/$name.c" > "$tmp/log" 2>&1; then
        bad "$mod" "the module's C does not compile with ASan"
        exit 1
    fi
    objs="$objs $tmp/mod_$name.o"
done

for f in tests/run/*.k; do
    [ -e "$f" ] || continue
    if ! "$KELVINC" --emit-c "$f" > "$tmp/prog.c" 2> "$tmp/log"; then
        bad "$f" "does not compile"
        continue
    fi
    if ! $CC $flags -I"$(dirname "$f")" -o "$tmp/prog" "$tmp/prog.c" $objs -lm > "$tmp/log" 2>&1; then
        bad "$f" "the C does not compile with ASan"
        continue
    fi
    want_status=$(sed -n 's|^[[:space:]]*// exit: *||p' "$f" | head -1)
    exits=$(grep -c 'SYS\.exit(' "$f")
    "$tmp/prog" > /dev/null 2> "$tmp/err"
    status=$?
    if grep -q "AddressSanitizer" "$tmp/err"; then
        cp "$tmp/err" "$tmp/log"
        bad "$f" "ASan reports an error"
        continue
    fi
    if [ "$status" -ne "${want_status:-0}" ]; then
        cp "$tmp/err" "$tmp/log"
        bad "$f" "exited with status $status"
        continue
    fi
    if [ -z "$want_status" ] && [ "$exits" -eq 0 ]; then
        live=$(sed -n 's/^allocations [0-9]*, live at exit //p' "$tmp/err" | tail -1)
        if [ "${live:-0}" -gt 0 ]; then
            : > "$tmp/log"
            bad "$f" "$live blocks live at exit: a leak"
            continue
        fi
    fi
    pass=$((pass + 1))
done
printf '%d passed, %d failed (ASan, %s)\n' "$pass" "$fail" "$CC"
[ "$fail" -eq 0 ]
