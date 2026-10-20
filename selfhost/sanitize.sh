#!/bin/sh
# selfhost/sanitize.sh - builds kc from stage2's C with AddressSanitizer
# and UndefinedBehaviorSanitizer, and checks that it writes the same C of
# kc and of sample.k as the stages do: kc has no memory error and no
# undefined behavior on its own source (#228). selfhost/bootstrap.sh
# comes first; CC picks the compiler, clang or gcc.
set -eu
cd "$(dirname "$0")/.."
out=build/selfhost
if [ ! -f "$out/stage2.c" ] || [ ! -f "$out/sample.c" ]; then
    echo "no stages: run selfhost/bootstrap.sh first"
    exit 1
fi
CC=${CC:-cc}
# what kc leaves at exit is not this check's: it frees its globals, and the
# libraries it links are kelvinc's, checked by tests/asan.sh
export ASAN_OPTIONS=detect_leaks=0
export UBSAN_OPTIONS=print_stacktrace=1

echo "kc with sanitizers: $CC"
$CC -std=c11 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=undefined -w \
    -isystem modules -o "$out/kc-sanitized" "$out/stage2.c" \
    modules/libkIO.a modules/libkOS.a modules/libkelvin.a -lm

"$out/kc-sanitized" selfhost/kc.k -c "$out/sanitized.c"
if cmp -s "$out/stage2.c" "$out/sanitized.c"; then
    echo "kc.k: the sanitized kc writes the C the stages write"
else
    echo "kc.k: the sanitized kc writes other C"
    diff "$out/stage2.c" "$out/sanitized.c" | head -20
    exit 1
fi

"$out/kc-sanitized" selfhost/sample.k -c "$out/sanitized-sample.c"
if cmp -s "$out/sample.c" "$out/sanitized-sample.c"; then
    echo "sample.k: the sanitized kc writes the C stage3 writes"
else
    echo "sample.k: the sanitized kc writes other C"
    diff "$out/sample.c" "$out/sanitized-sample.c" | head -20
    exit 1
fi
