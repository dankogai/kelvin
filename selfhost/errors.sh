#!/bin/sh
# selfhost/errors.sh - kc over tests/error/*.k, the programs kelvinc
# refuses, each with the text of its `// error: ...` line (#609). What kc
# does of each is one of five:
#   same   kc refuses it, and what is printed has that text
#   words  kc refuses it in words of its own, which are not kelvinc's
#   c      kc writes its C, and the C compiler refuses that
#   built  kc builds it: what kelvinc refuses is not refused
#   crash  kc itself ends, with no error of the program
# selfhost/errors.txt lists each test that is not `same`, with which of
# the four it is. This fails where a test is not as listed: one that got
# worse, and one that got better, whose line is to go, so that the list
# only shrinks; a new test of tests/error is the same in kc, or listed.
#   selfhost/errors.sh           checks, and prints the five counts
#   selfhost/errors.sh --write   writes selfhost/errors.txt anew, as kc is
# selfhost/bootstrap.sh comes first: kc is its stage3. Everything goes
# into build/selfhost/errors/; nothing is removed.
set -eu
cd "$(dirname "$0")/.."
kc=build/selfhost/stage3
list=selfhost/errors.txt
out=build/selfhost/errors
if [ ! -x "$kc" ]; then
    echo "no stages: run selfhost/bootstrap.sh first"
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
        if [ "$st" -lt 128 ] && LC_ALL=C grep -qF -- "$want" "$out/log"; then
            state=same
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
counts="$(count same) same, $(count words) words, $(count c) c, $(count built) built, $(count crash) crash of $(wc -l < "$out/now.txt" | tr -d ' ')"

if [ "${1:-}" = --write ]; then
    {
        echo "# selfhost/errors.txt - the tests of tests/error that kc does not refuse"
        echo "# in kelvinc's words (#609), each with what kc does of it: words, its"
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
            echo "$name: listed as $listed, and kc says kelvinc's words now: its line of $list is to go"
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
