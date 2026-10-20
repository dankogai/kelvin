#!/bin/sh
# selfhost/bootstrap.sh - builds kc, the compiler of selfhost/kc.k, in
# stages, as gcc bootstraps itself, and checks that it reaches a fixpoint:
#   stage1  kelvinc builds kc
#   stage2  stage1 builds kc
#   stage3  stage2 builds kc
# stage2 and stage3 are both kc built by kc, so the C each writes of kc
# must be the same, byte for byte. Then stage3 builds sample.k, whose
# output must be what kelvinc's build of it prints. Everything goes into
# build/selfhost/; nothing is removed.
set -eu
cd "$(dirname "$0")/.."
out=build/selfhost
mkdir -p "$out"
if [ ! -x ./kelvinc ] || [ ! -f modules/libkIO.a ]; then
    make
fi

echo "stage1: kelvinc builds kc"
./kelvinc selfhost/kc.k -o "$out/stage1"
echo "stage2: stage1 builds kc"
"$out/stage1" selfhost/kc.k -o "$out/stage2" -c "$out/stage2.c"
echo "stage3: stage2 builds kc"
"$out/stage2" selfhost/kc.k -o "$out/stage3" -c "$out/stage3.c"

if cmp -s "$out/stage2.c" "$out/stage3.c"; then
    echo "fixpoint: stage2 and stage3 write the same C of kc, $(wc -l < "$out/stage2.c" | tr -d ' ') lines"
else
    echo "no fixpoint: stage2 and stage3 write different C of kc"
    diff "$out/stage2.c" "$out/stage3.c" | head -20
    exit 1
fi

"$out/stage3" selfhost/sample.k -o "$out/sample" -c "$out/sample.c"
"$out/sample" > "$out/sample.kc.out"
./kelvinc -o "$out/sample.kelvinc" selfhost/sample.k
"$out/sample.kelvinc" > "$out/sample.kelvinc.out"
if cmp -s "$out/sample.kc.out" "$out/sample.kelvinc.out"; then
    echo "sample.k: stage3's build prints what kelvinc's prints"
else
    echo "sample.k: stage3's build and kelvinc's differ"
    diff "$out/sample.kc.out" "$out/sample.kelvinc.out"
    exit 1
fi
