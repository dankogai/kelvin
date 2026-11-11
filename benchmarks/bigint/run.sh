#!/bin/sh
# run.sh - races Kelvin's BigInt against GMP, Ruby, Python and Node on the
# cases of bench.k, best of 3 each, and prints a Markdown table, the fastest
# of each row in bold, the others with their ratio to it.
#
#   sh benchmarks/bigint/run.sh            # from anywhere
#
# It builds kelvinc's bench.k with -O and bench.c with -O2 against GMP into
# out/ beside this script, writes each one's lines to out/<name>.tsv and the
# table to out/results.md, and stops with status 1 where two disagree on a
# result.  A language it cannot find is left out, with a note.
#
# Environment:
#   KELVINC   kelvinc to build bench.k with (default: the repository's)
#   CC        the C compiler for bench.c (default: cc)
#   GMP_CFLAGS, GMP_LIBS
#             GMP's flags (default: pkg-config's, else the first of
#             /opt/local, /opt/homebrew, /usr/local and /usr with gmp.h)
#   RUBY, PYTHON, NODE
#             the interpreters (default: ruby; the newest python3.N on PATH,
#             else python3; node)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out="$here/out"
mkdir -p "$out"

KELVINC=${KELVINC:-$root/kelvinc}
CC=${CC:-cc}
RUBY=${RUBY:-ruby}
NODE=${NODE:-node}
if [ -z "${PYTHON:-}" ]; then
    PYTHON=python3
    for n in 20 19 18 17 16 15 14 13 12 11 10; do
        if command -v "python3.$n" >/dev/null 2>&1; then PYTHON="python3.$n"; break; fi
    done
fi

# GMP: pkg-config first, then the usual prefixes
if [ -z "${GMP_LIBS:-}" ]; then
    for p in /opt/local /opt/homebrew /usr/local; do
        if [ -f "$p/lib/pkgconfig/gmp.pc" ]; then
            PKG_CONFIG_PATH="$p/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
        fi
    done
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"
    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists gmp; then
        GMP_CFLAGS=$(pkg-config --cflags gmp)
        GMP_LIBS=$(pkg-config --libs gmp)
    else
        for p in /opt/local /opt/homebrew /usr/local /usr; do
            if [ -f "$p/include/gmp.h" ]; then
                GMP_CFLAGS="-I$p/include"
                GMP_LIBS="-L$p/lib -lgmp"
                break
            fi
        done
    fi
fi
GMP_CFLAGS=${GMP_CFLAGS:-}
GMP_LIBS=${GMP_LIBS:-}

names=""        # the columns, in order
add() { names="$names $1"; }

# the five, each of which writes out/<name>.tsv; a failure is a missing column
echo "building and running Kelvin ($KELVINC -O)" >&2
if [ -x "$KELVINC" ] && "$KELVINC" -O -o "$out/kelvin" "$here/bench.k"; then
    "$out/kelvin" > "$out/kelvin.tsv"
    add kelvin
else
    echo "note: Kelvin left out: no $KELVINC, or bench.k did not build" >&2
fi

echo "building and running GMP ($CC -O2 $GMP_CFLAGS $GMP_LIBS)" >&2
# shellcheck disable=SC2086
if $CC -std=c11 -O2 $GMP_CFLAGS -o "$out/gmp" "$here/bench.c" $GMP_LIBS; then
    "$out/gmp" > "$out/gmp.tsv"
    add gmp
else
    echo "note: GMP left out: bench.c did not build (set GMP_CFLAGS and GMP_LIBS)" >&2
fi

for lang in ruby python node; do
    case $lang in
        ruby)   exe=$RUBY;   src=bench.rb ;;
        python) exe=$PYTHON; src=bench.py ;;
        node)   exe=$NODE;   src=bench.mjs ;;
    esac
    if command -v "$exe" >/dev/null 2>&1; then
        echo "running $lang ($exe)" >&2
        "$exe" "$here/$src" > "$out/$lang.tsv"
        add $lang
    else
        echo "note: $lang left out: no $exe" >&2
    fi
done

[ -n "$names" ] || { echo "run.sh: nothing ran" >&2; exit 1; }

# the versions, for the table's heading
version() {
    case $1 in
        kelvin) "$KELVINC" --version 2>/dev/null | head -1 ;;
        gmp)    echo "GMP $("$out/gmp" --version)" ;;
        ruby)   # a Ruby built with GMP multiplies, divides and converts by it (#519)
                echo "$("$RUBY" -v | head -1), $("$RUBY" -e 'print defined?(Integer::GMP_VERSION) ? "with #{Integer::GMP_VERSION}" : "without GMP"')" ;;
        python) "$PYTHON" -V 2>&1 | head -1 ;;
        node)   echo "Node $("$NODE" -v)" ;;
    esac
}

cpu() {
    sysctl -n machdep.cpu.brand_string 2>/dev/null ||
        sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo 2>/dev/null | head -1 ||
        uname -m
}
os() {
    if command -v sw_vers >/dev/null 2>&1; then echo "macOS $(sw_vers -productVersion)"
    elif [ -r /etc/os-release ]; then . /etc/os-release && echo "$PRETTY_NAME"
    else uname -sr
    fi
}

status=0
{
    echo "| | |"
    echo "|:--|:--|"
    echo "| Machine | $(cpu) |"
    echo "| OS | $(os) |"
    echo "| C compiler | $($CC --version 2>/dev/null | head -1) |"
    for n in $names; do
        case $n in kelvin) t=Kelvin ;; gmp) t=GMP ;; ruby) t=Ruby ;; python) t=Python ;; node) t=Node ;; esac
        echo "| $t | $(version $n) |"
    done
    echo
    # shellcheck disable=SC2086
    awk -F '\t' -v names="$names" '
        BEGIN {
            label["sum"]       = "sum 1...100_000 (100k small ops)"
            label["fib"]       = "fib(10_000) (2,090 digits)"
            label["factorial"] = "factorial(1_000) (2,568 digits)"
            label["power"]     = "2 ** 100_000 (30,103 digits)"
            label["mul"]       = "10k-digit × 10k-digit, 100 times"
            label["div"]       = "20k-digit ÷ 10k-digit, 100 times"
            label["powmod"]    = "2060-bit modular power"
            label["gcd"]       = "gcd of two 1,000-digit numbers, 10 times"
            label["isqrt"]     = "isqrt of a 20k-digit number, 10 times"
            label["tostr"]     = "2 ** 100_000 to decimal text"
            label["parse"]     = "parse 10,000 decimal digits, 100 times"
            col["kelvin"] = "Kelvin"; col["gmp"] = "GMP"; col["ruby"] = "Ruby"
            col["python"] = "Python"; col["node"] = "Node"
            n = split(names, lang, " ")
        }
        FNR == 1 { file++ }
        {
            if (!($1 in seen)) { seen[$1] = 1; order[++rows] = $1 }
            t[$1, file] = $2
            if (($1, "check") in check && check[$1, "check"] != $3) {
                printf "run.sh: %s and %s disagree on %s: %s and %s\n", \
                    lang[1], lang[file], $1, check[$1, "check"], $3 > "/dev/stderr"
                bad = 1
            }
            check[$1, "check"] = $3
        }
        function fmt(s) {
            if (s < 0.001) return sprintf("%.2f µs", s * 1e6)
            if (s < 1)     return sprintf("%.2f ms", s * 1e3)
            return sprintf("%.2f s", s)
        }
        END {
            head = "| Benchmark |"; rule = "|:--|"
            for (i = 1; i <= n; i++) { head = head " " col[lang[i]] " |"; rule = rule "--:|" }
            print head; print rule
            for (r = 1; r <= rows; r++) {
                id = order[r]; best = -1
                for (i = 1; i <= n; i++)
                    if ((id, i) in t && (best < 0 || t[id, i] + 0 < best)) best = t[id, i] + 0
                line = "| " (id in label ? label[id] : id) " |"
                for (i = 1; i <= n; i++) {
                    if (!((id, i) in t)) { line = line " – |"; continue }
                    v = t[id, i] + 0
                    if (v == best || best == 0) line = line " **" fmt(v) "** |"
                    else line = line sprintf(" %s (%.1f×) |", fmt(v), v / best)
                }
                print line
            }
            exit bad
        }
    ' $(for n in $names; do echo "$out/$n.tsv"; done)
} > "$out/results.md" || status=$?

cat "$out/results.md"
exit "${status:-0}"
