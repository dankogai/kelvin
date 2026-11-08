#!/bin/sh
# tests/fetch.sh (#482): the programs of tests/fetch, which fetch from
# tests/fetch/server.py on 127.0.0.1, with no network beyond: HTTP always,
# and HTTPS where libkfetch was built with HAS_SSL=1, from a server whose
# certificate is made here and trusted through SSL_CERT_FILE, and from one
# whose certificate is not. A program takes the base URLs, http://, https://
# and the untrusted https://, and its output shows them as BASE, TLSBASE and
# BADBASE, so that its // out: lines hold no port. One with // needs: ssl
# runs only with HTTPS built in, and one with // needs: nossl only without.
set -u
cd "$(dirname "$0")/.." || exit 1
KELVINC=${KELVINC:-./kelvinc}
if ! command -v python3 >/dev/null 2>&1; then
    echo "tests/fetch.sh skipped: no python3"
    exit 0
fi
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kelvin-fetch.XXXXXX") || exit 1
[ -n "$tmp" ] && [ -d "$tmp" ] || exit 1
case $tmp in
/*) ;;
*) tmp=$(pwd)/$tmp ;;
esac
pids=
trap 'for p in $pids; do kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; done; rm -rf "$tmp"' EXIT

pass=0
fail=0
bad() {
    fail=$((fail + 1))
    printf 'FAIL %s: %s\n' "$1" "$2"
    [ -s "$tmp/log" ] && sed 's/^/    /' "$tmp/log" | head -20
}

# a server writing its port to $1, with a certificate and key after it for
# HTTPS; nothing to read, so that no prompt waits
serve() {
    python3 -I tests/fetch/server.py "$@" < /dev/null > "$1.log" 2>&1 &
    pids="$pids $!"
    i=0
    while [ ! -s "$1" ] && [ $i -lt 300 ]; do
        sleep 0.1
        i=$((i + 1))
    done
    if [ ! -s "$1" ]; then
        cat "$1.log" >&2
        echo "tests/fetch.sh: the server of $* did not start; $(python3 --version 2>&1), $(openssl version 2>&1)" >&2
        exit 1
    fi
}

# a certificate for 127.0.0.1 and localhost, good for a day, and its key,
# made apart, by genpkey, which writes it unencrypted however openssl's req
# takes -nodes
certify() {
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$tmp/$1.key" > "$tmp/log" 2>&1 &&
        openssl req -x509 -new -key "$tmp/$1.key" -out "$tmp/$1.pem" -days 1 \
            -subj /CN=localhost -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" >> "$tmp/log" 2>&1
}

serve "$tmp/port"
base="http://127.0.0.1:$(cat "$tmp/port")"
ssl=no
grep -q ssl modules/libkfetch.link 2>/dev/null && ssl=yes
tlsbase=https://127.0.0.1:1
badbase=https://127.0.0.1:1
if [ $ssl = yes ]; then
    if ! command -v openssl >/dev/null 2>&1; then
        echo "tests/fetch.sh: HTTPS is built in, but there is no openssl to make a certificate" >&2
        exit 1
    fi
    certify good || { bad tests/fetch.sh "openssl did not make a certificate"; exit 1; }
    certify other || { bad tests/fetch.sh "openssl did not make a certificate"; exit 1; }
    serve "$tmp/tport" "$tmp/good.pem" "$tmp/good.key"
    serve "$tmp/bport" "$tmp/other.pem" "$tmp/other.key"
    tlsbase="https://127.0.0.1:$(cat "$tmp/tport")"
    badbase="https://127.0.0.1:$(cat "$tmp/bport")"
fi

for f in tests/fetch/*.k; do
    [ -e "$f" ] || continue
    needs=$(sed -n 's|^// needs: *||p' "$f" | head -1)
    [ "$needs" = ssl ] && [ $ssl = no ] && continue
    [ "$needs" = nossl ] && [ $ssl = yes ] && continue
    sed -n 's|^[[:space:]]*// out: \{0,1\}||p' "$f" > "$tmp/expected"
    if ! "$KELVINC" "$f" -o "$tmp/prog" > "$tmp/log" 2>&1; then
        bad "$f" "does not compile"
        continue
    fi
    SSL_CERT_FILE="$tmp/good.pem" "$tmp/prog" "$base" "$tlsbase" "$badbase" > "$tmp/raw" 2> "$tmp/log"
    status=$?
    sed -e "s|$badbase|BADBASE|g" -e "s|$tlsbase|TLSBASE|g" -e "s|$base|BASE|g" "$tmp/raw" > "$tmp/actual"
    if [ $status -ne 0 ]; then
        bad "$f" "exited with status $status"
        continue
    fi
    if ! cmp -s "$tmp/expected" "$tmp/actual"; then
        diff "$tmp/expected" "$tmp/actual" > "$tmp/log"
        bad "$f" "output differs (expected < > actual)"
        continue
    fi
    pass=$((pass + 1))
done
echo "$pass passed, $fail failed (fetch, HTTPS $ssl)"
[ $fail -eq 0 ]
