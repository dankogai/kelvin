#!/bin/sh
# selfhost/errors.sh - kc over tests/error/*.k, the programs kelvinc
# refuses, each with the text of its `// error: ...` line (#609). What kc
# does of each is one of six:
#   same   kc refuses it, and what is printed has that text, at the line
#          and column kelvinc says it at, where both refuse it themselves
#   place  as same, and at another line or column than kelvinc's (#690)
#   words  kc refuses it in words of its own, which are not kelvinc's
#   c      kc writes its C, and the C compiler refuses that
#   built  kc builds it: what kelvinc refuses is not refused
#   crash  kc itself ends, with no error of the program, or after one, as
#          a check of its own says, 'kelvin: index ... is out of range' (#624)
# selfhost/errors.txt lists each test that is not `same`, with which of
# the five it is. This fails where a test is not as listed: one that got
# worse, and one that got better, whose line is to go, so that the list
# only shrinks; a new test of tests/error is the same in kc, or listed.
#   selfhost/errors.sh           checks, and prints the six counts
#   selfhost/errors.sh --write   writes selfhost/errors.txt anew, as kc is
# selfhost/bootstrap.sh comes first: kc is its stage3. Everything goes
# into build/selfhost/errors/; nothing is removed.
set -eu
cd "$(dirname "$0")/.."
kc=build/selfhost/stage3
kelvinc=./kelvinc
list=selfhost/errors.txt
out=build/selfhost/errors
if [ ! -x "$kc" ]; then
    echo "no stages: run selfhost/bootstrap.sh first"
    exit 1
fi
if [ ! -x "$kelvinc" ]; then
    echo "no kelvinc: run make first"
    exit 1
fi
mkdir -p "$out"

: > "$out/now.txt"
for f in tests/error/*.k; do
    [ -e "$f" ] || continue
    # bytes, not characters, as tests/run.sh reads it (#485)
    want=$(LC_ALL=C sed -n 's|^[[:space:]]*// error: ||p' "$f" | head -1)
    st=0
    "$kc" --emit-c -o "$out/prog.c" "$f" > "$out/log" 2>&1 || st=$?
    if [ "$st" -ne 0 ]; then
        if LC_ALL=C grep -q "^kelvin: " "$out/log"; then
            state=crash # kc's own check ended it, after an error too (#624)
        elif [ "$st" -lt 128 ] && LC_ALL=C grep -qF -- "$want" "$out/log"; then
            state=same
            # where it is: file:line:col of the first error, kelvinc's and
            # kc's, where kelvinc refuses it itself too (#690)
            at_kc=$(LC_ALL=C grep -m1 -oE '^[^ ]*\.kh?:[0-9]+(:[0-9]+)?: error' "$out/log" || true)
            at_kelvinc=$("$kelvinc" --emit-c -o "$out/kelvinc.c" "$f" 2>&1 | LC_ALL=C grep -m1 -oE '^[^ ]*\.kh?:[0-9]+(:[0-9]+)?: error' || true)
            if [ -n "$at_kelvinc" ] && [ "$at_kc" != "$at_kelvinc" ]; then
                state=place
            fi
        elif [ "$st" -lt 128 ] && LC_ALL=C grep -q -e ": error: " -e "^kc: " "$out/log"; then
            state=words # an error at a line, or kc's of a file it cannot read
        else
            state=crash
        fi
    elif "$kc" -o "$out/prog" "$f" > "$out/log" 2>&1; then
        state=built
    elif LC_ALL=C grep -qF -- "$want" "$out/log"; then
        state=same
    else
        state=c
    fi
    echo "$state ${f#tests/error/}" >> "$out/now.txt"
done

count() { grep -c "^$1 " "$out/now.txt" || true; }
counts="$(count same) same, $(count place) place, $(count words) words, $(count c) c, $(count built) built, $(count crash) crash of $(wc -l < "$out/now.txt" | tr -d ' ')"

if [ "${1:-}" = --write ]; then
    {
        echo "# selfhost/errors.txt - the tests of tests/error that kc does not refuse"
        echo "# in kelvinc's words at kelvinc's place (#609, #690), each with what kc"
        echo "# does of it: place, its words at another line or column; words, its"
        echo "# own; c, the C compiler's; built; crash. selfhost/errors.sh checks kc"
        echo "# against it, and writes it anew with --write. A line goes as kc learns"
        echo "# the error."
        grep -v "^same " "$out/now.txt" || true
    } > "$list"
    echo "kc over tests/error: $counts; $list written"
    exit 0
fi

# every test with its state as listed, same where it is not listed
grep -v "^#" "$list" > "$out/listed.txt" || true
bad=0
while read -r state name; do
    if [ ! -e "tests/error/$name" ]; then
        echo "$name: listed as $state, and tests/error has no such test"
        bad=$((bad + 1))
    fi
done < "$out/listed.txt"
while read -r state name; do
    listed=$(awk -v name="$name" '$2 == name { print $1; exit }' "$out/listed.txt")
    listed=${listed:-same}
    if [ "$state" != "$listed" ]; then
        if [ "$state" = same ]; then
            echo "$name: listed as $listed, and kc says kelvinc's words at kelvinc's place now: its line of $list is to go"
        else
            echo "$name: $listed as listed, and kc's is $state now"
        fi
        bad=$((bad + 1))
    fi
done < "$out/now.txt"

if [ "$bad" -ne 0 ]; then
    echo "kc over tests/error: $counts; $bad not as $list has them"
    exit 1
fi
echo "kc over tests/error: $counts, as $list has them"
