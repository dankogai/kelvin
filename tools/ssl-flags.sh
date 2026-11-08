#!/bin/sh
# tools/ssl-flags.sh --cflags|--libs (#482): OpenSSL's flags for libkfetch,
# HTTPS for #import <fetch>, the first of these that compiles and links a
# TLS client with $CC: SSL_CFLAGS and SSL_LIBS as given; pkg-config's
# openssl; Homebrew's openssl@3; MacPorts' /opt/local; /usr/local, as
# FreeBSD's ports; the system's own, as FreeBSD's base and Linux's
# libssl-dev. Prints nothing, and exits 1, where none does.
set -u
want=${1:---libs}
cc=${CC:-cc}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kelvin-ssl.XXXXXX") || exit 1
[ -n "$tmp" ] && [ -d "$tmp" ] || exit 1
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/t.c" <<'EOF'
#include <openssl/ssl.h>
#include <openssl/x509v3.h>
int main(void) {
    SSL_CTX *c = SSL_CTX_new(TLS_client_method());
    SSL_CTX_set_min_proto_version(c, TLS1_2_VERSION);
    SSL_CTX_free(c);
    return 0;
}
EOF
works() { # cflags libs
    # shellcheck disable=SC2086
    "$cc" $1 -o "$tmp/t" "$tmp/t.c" $2 >/dev/null 2>&1
}
found() {
    if [ "$want" = --cflags ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi
    exit 0
}
if [ -n "${SSL_CFLAGS:-}${SSL_LIBS:-}" ]; then
    works "${SSL_CFLAGS:-}" "${SSL_LIBS:--lssl -lcrypto}" && found "${SSL_CFLAGS:-}" "${SSL_LIBS:--lssl -lcrypto}"
    exit 1
fi
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists openssl 2>/dev/null; then
    c=$(pkg-config --cflags openssl) l=$(pkg-config --libs openssl)
    works "$c" "$l" && found "$c" "$l"
fi
if command -v brew >/dev/null 2>&1; then
    p=$(brew --prefix openssl@3 2>/dev/null) || p=
    [ -n "$p" ] && [ -d "$p/include" ] && works "-I$p/include" "-L$p/lib -lssl -lcrypto" &&
        found "-I$p/include" "-L$p/lib -lssl -lcrypto"
fi
for p in /opt/homebrew/opt/openssl@3 /usr/local/opt/openssl@3 /opt/local /usr/local; do
    [ -f "$p/include/openssl/ssl.h" ] && works "-I$p/include" "-L$p/lib -lssl -lcrypto" &&
        found "-I$p/include" "-L$p/lib -lssl -lcrypto"
done
works "" "-lssl -lcrypto" && found "" "-lssl -lcrypto"
exit 1
