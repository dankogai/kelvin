/* fetch.c - the engine of #import <fetch> (#482): JS's fetch(url), a GET
   over HTTP/1.1, of our own over sockets, following redirects as JS's does,
   up to 20. HTTPS is OpenSSL's where libkfetch is built with HAS_SSL=1,
   which defines KV_HAS_SSL; else an https URL is an error that says so.
   Each request says Connection: close and Accept-Encoding: identity, so a
   response ends where its Content-Length, its last chunk or the connection
   does, and its body is as sent. */
/* POSIX under -std=c11, which hides getaddrinfo and its kin, as os.c has it */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#elif !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)
#define _XOPEN_SOURCE 700
#define _DEFAULT_SOURCE 1
#endif
#include "kelvin_prelude.h"
#include "kfetch.h"

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <pthread.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#ifdef KV_HAS_SSL
#include <openssl/err.h>
#include <openssl/ssl.h>
#include <openssl/x509v3.h>
#endif

enum { MAX_REDIRECTS = 20, TIMEOUT_SECONDS = 60 };

bool kfetch_has_ssl(void) {
#ifdef KV_HAS_SSL
    return true;
#else
    return false;
#endif
}

/* ---------- text ---------- */

/* a String of n bytes of p: UTF-8 as it is, else each byte past ASCII
   read as Latin-1, as HTTP's old header text was; NULs dropped */
static kv_string text_of(const void *p, size_t n) {
    const uint8_t *s = p;
    kv_bytes b = kv_bytes_new();
    size_t count;
    bool utf8 = kv_utf8_valid(s, n, &count);
    for (size_t i = 0; i < n; i++) {
        if (!s[i])
            continue;
        if (utf8 || s[i] < 0x80) {
            kv_bytes_push(&b, s[i]);
        } else {
            kv_bytes_push(&b, (uint8_t)(0xC0 | s[i] >> 6));
            kv_bytes_push(&b, (uint8_t)(0x80 | (s[i] & 0x3F)));
        }
    }
    kv_string out = kv_string_from_bytes(&b);
    kv_bytes_free(&b);
    return out;
}

static void fail(kv_string *error, const char *fmt, ...) __attribute__((format(printf, 2, 3)));
static void fail(kv_string *error, const char *fmt, ...) {
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    kv_string_free(error);
    *error = text_of(buf, strlen(buf));
}

/* ---------- URLs ---------- */

/* a malloc'd copy of s, by malloc, which a counting allocator sees */
static char *copy_text(const char *s) {
    size_t n = strlen(s) + 1;
    char *c = malloc(n);
    if (!c)
        abort();
    memcpy(c, s, n);
    return c;
}

typedef struct {
    bool https;
    char host[256];   /* a name, or an address, an IPv6 one without its [] */
    char port[8];     /* as written, or 80 or 443 */
    bool port_given;
    char *target;     /* the path and the query, "/" at least, malloc'd */
} url_t;

static bool parse_url(const char *u, url_t *out, kv_string *error) {
    memset(out, 0, sizeof *out);
    for (const unsigned char *c = (const unsigned char *)u; *c; c++)
        if (*c <= ' ' || *c == 0x7F) {
            fail(error, "fetch: a URL has no spaces or control characters: %s", u);
            return false;
        }
    const char *rest;
    if (!strncasecmp(u, "http://", 7)) {
        rest = u + 7;
    } else if (!strncasecmp(u, "https://", 8)) {
        rest = u + 8;
        out->https = true;
    } else {
        fail(error, "fetch: a URL starts with http:// or https://, and this is %s", u);
        return false;
    }
    size_t alen = strcspn(rest, "/?#");
    const char *auth = rest, *after = rest + alen;
    if (memchr(auth, '@', alen)) {
        fail(error, "fetch: a URL with a user, user@host, is not taken: %s", u);
        return false;
    }
    const char *colon = NULL;
    if (alen && auth[0] == '[') { /* [::1]:8080 */
        const char *close = memchr(auth, ']', alen);
        if (!close || close - auth - 1 >= (long)sizeof out->host) {
            fail(error, "fetch: this URL's IPv6 address has no ']': %s", u);
            return false;
        }
        memcpy(out->host, auth + 1, (size_t)(close - auth - 1));
        if (close + 1 < after) {
            if (close[1] != ':') {
                fail(error, "fetch: this URL has something after its address's ']': %s", u);
                return false;
            }
            colon = close + 1;
        }
    } else {
        colon = memchr(auth, ':', alen);
        size_t hlen = colon ? (size_t)(colon - auth) : alen;
        if (hlen >= sizeof out->host) {
            fail(error, "fetch: this URL's host is longer than 255 bytes: %s", u);
            return false;
        }
        memcpy(out->host, auth, hlen);
    }
    if (!out->host[0]) {
        fail(error, "fetch: this URL has no host: %s", u);
        return false;
    }
    if (colon) {
        size_t plen = (size_t)(after - colon - 1);
        long port = 0;
        for (size_t i = 0; i < plen; i++) {
            if (colon[1 + i] < '0' || colon[1 + i] > '9' || port > 65535) {
                port = -1;
                break;
            }
            port = port * 10 + (colon[1 + i] - '0');
        }
        if (!plen || port < 1 || port > 65535) {
            fail(error, "fetch: this URL's port is not one from 1 to 65535: %s", u);
            return false;
        }
        snprintf(out->port, sizeof out->port, "%ld", port);
        out->port_given = true;
    } else {
        strcpy(out->port, out->https ? "443" : "80");
    }
    size_t tlen = strcspn(after, "#");
    bool slash = tlen && after[0] == '/';
    out->target = malloc(tlen + 2);
    if (!out->target)
        abort();
    snprintf(out->target, tlen + 2, "%s%.*s", slash ? "" : "/", (int)tlen, after);
    return true;
}

/* the URL u is, written out: what the Response's url says */
static char *url_text(const url_t *u) {
    bool v6 = strchr(u->host, ':') != NULL;
    bool plain = !strcmp(u->port, u->https ? "443" : "80");
    size_t n = strlen(u->host) + strlen(u->target) + 32;
    char *s = malloc(n);
    if (!s)
        abort();
    snprintf(s, n, "%s://%s%s%s%s%s%s", u->https ? "https" : "http", v6 ? "[" : "", u->host, v6 ? "]" : "",
             plain ? "" : ":", plain ? "" : u->port, u->target);
    return s;
}

/* path without its . and .. segments, RFC 3986's remove_dot_segments, in
   place, as far as its query */
static void remove_dots(char *path) {
    size_t qlen = strcspn(path, "?#");
    char *query = copy_text(path + qlen), *in = malloc(qlen + 1);
    if (!query || !in)
        abort();
    memcpy(in, path, qlen);
    in[qlen] = 0;
    char *p = in;
    size_t o = 0;
    while (*p) {
        if (!strncmp(p, "../", 3)) {
            p += 3;
        } else if (!strncmp(p, "./", 2) || !strncmp(p, "/./", 3)) {
            p += 2; /* "./x" is "x", "/./x" "/x" */
        } else if (!strcmp(p, "/.")) {
            p[1] = 0;
        } else if (!strncmp(p, "/../", 4) || !strcmp(p, "/..")) {
            if (p[3] == '/') {
                p += 3; /* "/../x" goes on as "/x" */
            } else {
                p += 2;
                *p = '/'; /* "/.." as "/" */
            }
            while (o > 0 && path[o - 1] != '/')
                o--;
            if (o > 0)
                o--;
        } else if (!strcmp(p, ".") || !strcmp(p, "..")) {
            break;
        } else {
            do
                path[o++] = *p++;
            while (*p && *p != '/');
        }
    }
    path[o] = 0;
    strcat(path, query);
    free(in);
    free(query);
}

/* the URL that a Location of loc means from base: absolute, //host...,
   /path, ?query, or a path beside base's, without . and .. */
static char *resolve(const url_t *base, const char *loc) {
    if (!strncasecmp(loc, "http://", 7) || !strncasecmp(loc, "https://", 8))
        return copy_text(loc);
    char *b = url_text(base);
    size_t n = strlen(b) + strlen(loc) + 16;
    char *s = malloc(n);
    if (!s)
        abort();
    if (loc[0] == '/' && loc[1] == '/') {
        snprintf(s, n, "%s:%s", base->https ? "https" : "http", loc);
    } else {
        size_t origin = strlen(b) - strlen(base->target); /* scheme://host:port */
        if (loc[0] == '/') {
            snprintf(s, n, "%.*s%s", (int)origin, b, loc);
        } else if (loc[0] == '?') {
            snprintf(s, n, "%.*s%.*s%s", (int)origin, b, (int)strcspn(base->target, "?"), base->target, loc);
        } else {
            size_t path = strcspn(base->target, "?"), dir = path;
            while (dir > 0 && base->target[dir - 1] != '/')
                dir--;
            snprintf(s, n, "%.*s%.*s%s", (int)origin, b, (int)dir, base->target, loc);
        }
        if (loc[0] != '?')
            remove_dots(s + origin);
    }
    free(b);
    return s;
}

/* ---------- connections ---------- */

typedef struct {
    int fd;
#ifdef KV_HAS_SSL
    SSL_CTX *ctx;
    SSL *ssl;
#endif
} conn_t;

static void conn_close(conn_t *c) {
#ifdef KV_HAS_SSL
    if (c->ssl) {
        SSL_shutdown(c->ssl);
        SSL_free(c->ssl);
    }
    if (c->ctx)
        SSL_CTX_free(c->ctx);
    c->ssl = NULL;
    c->ctx = NULL;
#endif
    if (c->fd >= 0)
        close(c->fd);
    c->fd = -1;
}

#ifdef KV_HAS_SSL
/* what OpenSSL says went wrong last, or else what */
static const char *ssl_reason(const char *otherwise) {
    unsigned long e = ERR_get_error();
    static _Thread_local char buf[256];
    if (!e)
        return otherwise;
    ERR_error_string_n(e, buf, sizeof buf);
    return buf;
}

static bool tls_start(conn_t *c, const url_t *u, kv_string *error) {
    c->ctx = SSL_CTX_new(TLS_client_method());
    if (!c->ctx) {
        fail(error, "fetch: TLS could not start: %s", ssl_reason("no context"));
        return false;
    }
    SSL_CTX_set_min_proto_version(c->ctx, TLS1_2_VERSION);
#ifdef SSL_OP_IGNORE_UNEXPECTED_EOF
    SSL_CTX_set_options(c->ctx, SSL_OP_IGNORE_UNEXPECTED_EOF); /* a server that closes without close_notify */
#endif
    SSL_CTX_set_default_verify_paths(c->ctx); /* SSL_CERT_FILE and SSL_CERT_DIR too */
    SSL_CTX_set_verify(c->ctx, SSL_VERIFY_PEER, NULL);
    c->ssl = SSL_new(c->ctx);
    if (!c->ssl) {
        fail(error, "fetch: TLS could not start: %s", ssl_reason("no session"));
        return false;
    }
    SSL_set_fd(c->ssl, c->fd);
    struct in6_addr a6;
    struct in_addr a4;
    bool address = inet_pton(AF_INET, u->host, &a4) == 1 || inet_pton(AF_INET6, u->host, &a6) == 1;
    if (address) {
        X509_VERIFY_PARAM_set1_ip_asc(SSL_get0_param(c->ssl), u->host);
    } else {
        SSL_set_tlsext_host_name(c->ssl, u->host); /* SNI */
        SSL_set1_host(c->ssl, u->host);
    }
    if (SSL_connect(c->ssl) != 1) {
        long v = SSL_get_verify_result(c->ssl);
        if (v != X509_V_OK)
            fail(error, "fetch: the certificate of %s is not trusted: %s", u->host, X509_verify_cert_error_string(v));
        else
            fail(error, "fetch: TLS with %s failed: %s", u->host, ssl_reason("the handshake did not finish"));
        return false;
    }
    return true;
}
#endif

static bool conn_open(conn_t *c, const url_t *u, kv_string *error) {
    c->fd = -1;
#ifdef KV_HAS_SSL
    c->ctx = NULL;
    c->ssl = NULL;
#else
    if (u->https) {
        fail(error, "fetch: HTTPS is not built in: libkfetch was built with HAS_SSL=0");
        return false;
    }
#endif
    struct addrinfo hints = {0}, *res = NULL;
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    int g = getaddrinfo(u->host, u->port, &hints, &res);
    if (g) {
        fail(error, "fetch: cannot find the host %s: %s", u->host, gai_strerror(g));
        return false;
    }
    int err = 0;
    for (struct addrinfo *a = res; a; a = a->ai_next) {
        int fd = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
        if (fd < 0) {
            err = errno;
            continue;
        }
        struct timeval tv = {TIMEOUT_SECONDS, 0};
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);
#ifdef SO_NOSIGPIPE
        int one = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof one);
#endif
        if (connect(fd, a->ai_addr, a->ai_addrlen) == 0) {
            c->fd = fd;
            break;
        }
        err = errno;
        close(fd);
    }
    freeaddrinfo(res);
    if (c->fd < 0) {
        fail(error, "fetch: cannot connect to %s port %s: %s", u->host, u->port, strerror(err));
        return false;
    }
#ifdef KV_HAS_SSL
    if (u->https && !tls_start(c, u, error))
        return false;
#endif
    return true;
}

static bool conn_write(conn_t *c, const char *p, size_t n, kv_string *error) {
#if !defined(SO_NOSIGPIPE)
    /* a peer that has closed would raise SIGPIPE in this thread: held
       back while writing, and taken if it came (MSG_NOSIGNAL is not
       OpenSSL's to give) */
    sigset_t pipe, old;
    sigemptyset(&pipe);
    sigaddset(&pipe, SIGPIPE);
    pthread_sigmask(SIG_BLOCK, &pipe, &old);
#endif
    bool ok = true;
    while (n > 0) {
        long w;
#ifdef KV_HAS_SSL
        if (c->ssl)
            w = SSL_write(c->ssl, p, (int)n);
        else
#endif
            w = (long)send(c->fd, p, n, 0);
        if (w <= 0) {
            if (w < 0 && errno == EINTR)
                continue;
            fail(error, "fetch: the request could not be sent: %s", strerror(errno));
            ok = false;
            break;
        }
        p += w;
        n -= (size_t)w;
    }
#if !defined(SO_NOSIGPIPE)
    struct timespec zero = {0, 0};
    while (sigtimedwait(&pipe, NULL, &zero) > 0)
        ;
    pthread_sigmask(SIG_SETMASK, &old, NULL);
#endif
    return ok;
}

/* bytes read into buf: 0 at the end, -1 where it failed, with error */
static long conn_read(conn_t *c, char *buf, size_t n, kv_string *error) {
    for (;;) {
#ifdef KV_HAS_SSL
        if (c->ssl) {
            int r = SSL_read(c->ssl, buf, (int)n);
            if (r > 0)
                return r;
            int e = SSL_get_error(c->ssl, r);
            if (e == SSL_ERROR_ZERO_RETURN)
                return 0;
            if (e == SSL_ERROR_SYSCALL && !ERR_peek_error() && (r == 0 || errno == 0))
                return 0; /* closed without close_notify */
            fail(error, "fetch: reading over TLS failed: %s", ssl_reason(strerror(errno)));
            return -1;
        }
#endif
        long r = (long)recv(c->fd, buf, n, 0);
        if (r >= 0)
            return r;
        if (errno == EINTR)
            continue;
        fail(error, "fetch: reading the response failed: %s",
             errno == EAGAIN || errno == EWOULDBLOCK ? "no answer in 60 seconds" : strerror(errno));
        return -1;
    }
}

/* ---------- responses ---------- */

/* the offset just past the blank line that ends the headers from start,
   0 where it has not come yet */
static size_t head_end(const kv_bytes *in, size_t start) {
    for (size_t i = start; i + 1 < in->count; i++) {
        if (in->at[i] != '\n')
            continue;
        if (in->at[i + 1] == '\n')
            return i + 2;
        if (i + 2 < in->count && in->at[i + 1] == '\r' && in->at[i + 2] == '\n')
            return i + 3;
    }
    return 0;
}

/* the value of the header name in the block from p to end, or NULL;
   its length in *n */
static const char *header_in(const char *p, const char *end, const char *name, size_t *n) {
    size_t len = strlen(name);
    while (p < end) {
        const char *eol = memchr(p, '\n', (size_t)(end - p));
        if (!eol)
            eol = end;
        if ((size_t)(eol - p) > len && !strncasecmp(p, name, len) && p[len] == ':') {
            const char *v = p + len + 1, *e = eol;
            while (v < e && (*v == ' ' || *v == '\t'))
                v++;
            while (e > v && (e[-1] == '\r' || e[-1] == ' ' || e[-1] == '\t'))
                e--;
            *n = (size_t)(e - v);
            return v;
        }
        p = eol + 1;
    }
    return NULL;
}

static bool has_token(const char *v, size_t n, const char *token) {
    size_t t = strlen(token);
    for (size_t i = 0; i + t <= n; i++)
        if (!strncasecmp(v + i, token, t))
            return true;
    return false;
}

/* the body of a chunked encoding at p, n bytes, into out: 1 when it is
   whole, 0 when more is to come, -1 where it is not one */
static int dechunk(const uint8_t *p, size_t n, kv_bytes *out) {
    size_t i = 0;
    out->count = 0;
    for (;;) {
        unsigned long long size = 0;
        size_t digits = 0;
        while (i < n) {
            uint8_t c = p[i];
            int d = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
            if (d < 0)
                break;
            if (size > (1ull << 56))
                return -1;
            size = size * 16 + (unsigned)d;
            digits++;
            i++;
        }
        const uint8_t *eol = i < n ? memchr(p + i, '\n', n - i) : NULL;
        if (!eol)
            return 0;
        if (!digits)
            return -1;
        i = (size_t)(eol - p) + 1; /* past any extension */
        if (!size) { /* the last chunk, then trailers up to a blank line */
            for (;;) {
                const uint8_t *e = i < n ? memchr(p + i, '\n', n - i) : NULL;
                if (!e)
                    return 0;
                size_t len = (size_t)(e - (p + i));
                i = (size_t)(e - p) + 1;
                if (len == 0 || (len == 1 && e[-1] == '\r'))
                    return 1;
            }
        }
        if (n - i < size)
            return 0;
        kv_bytes_append(out, p + i, (size_t)size);
        i += (size_t)size;
        if (i < n && p[i] == '\r')
            i++;
        if (i >= n)
            return 0;
        if (p[i] != '\n')
            return -1;
        i++;
    }
}

typedef struct {
    int status;
    kv_string status_text;
    kv_bytes headers; /* name\0value\0 ... */
    kv_bytes body;
    char *location;   /* of a redirect, malloc'd */
} response_t;

/* one GET of u: the response, or false with error */
static bool get_once(const url_t *u, response_t *r, kv_string *error) {
    conn_t c;
    if (!conn_open(&c, u, error)) {
        conn_close(&c);
        return false;
    }
    bool v6 = strchr(u->host, ':') != NULL;
    size_t n = strlen(u->target) + strlen(u->host) + 256;
    char *req = malloc(n);
    if (!req)
        abort();
    snprintf(req, n,
             "GET %s HTTP/1.1\r\nHost: %s%s%s%s%s\r\nUser-Agent: Kelvin-fetch\r\nAccept: */*\r\n"
             "Accept-Encoding: identity\r\nConnection: close\r\n\r\n",
             u->target, v6 ? "[" : "", u->host, v6 ? "]" : "", u->port_given ? ":" : "", u->port_given ? u->port : "");
    bool sent = conn_write(&c, req, strlen(req), error);
    free(req);
    if (!sent) {
        conn_close(&c);
        return false;
    }
    kv_bytes in = kv_bytes_new();
    char buf[16384];
    size_t start = 0, end = 0;  /* the final header block, past any 1xx */
    long long length = -1;      /* its Content-Length */
    bool chunked = false, bodyless = false, ok = true, whole = false;
    for (;;) {
        if (end && !bodyless && !chunked && length >= 0 && in.count - end >= (unsigned long long)length) {
            whole = true;
            break;
        }
        if (end && bodyless) {
            whole = true;
            break;
        }
        if (end && chunked && in.count >= end + 5 && !memcmp(in.at + in.count - 4, "\r\n\r\n", 4)) {
            kv_bytes probe = kv_bytes_new();
            int d = dechunk(in.at + end, in.count - end, &probe);
            kv_bytes_free(&probe);
            if (d) {
                whole = true;
                break;
            }
        }
        long got = conn_read(&c, buf, sizeof buf, error);
        if (got < 0) {
            ok = false;
            break;
        }
        if (got == 0)
            break;
        kv_bytes_append(&in, buf, (size_t)got);
        while (!end) {
            size_t e = head_end(&in, start);
            if (!e)
                break;
            const char *line = (const char *)in.at + start;
            int status = 0;
            if (e - start < 12 || strncmp(line, "HTTP/1.", 7) || line[8] != ' ' ||
                sscanf(line + 9, "%3d", &status) != 1 || status < 100 || status > 999) {
                fail(error, "fetch: %s did not answer in HTTP/1.1", u->host);
                ok = false;
                break;
            }
            if (status >= 100 && status < 200 && status != 101) { /* 100 Continue and the like: the next block */
                start = e;
                continue;
            }
            r->status = status;
            end = e;
            size_t hl;
            const char *h = (const char *)in.at + start, *he = (const char *)in.at + end;
            const char *te = header_in(h, he, "transfer-encoding", &hl);
            chunked = te && has_token(te, hl, "chunked");
            const char *cl = header_in(h, he, "content-length", &hl);
            if (cl && !chunked) {
                length = 0;
                for (size_t i = 0; i < hl && cl[i] >= '0' && cl[i] <= '9' && length < (1ll << 50); i++)
                    length = length * 10 + (cl[i] - '0');
            }
            bodyless = status == 204 || status == 304;
        }
        if (!ok)
            break;
    }
    conn_close(&c);
    if (ok && !end) {
        fail(error, "fetch: %s closed the connection before its response's headers ended", u->host);
        ok = false;
    }
    if (ok) {
        /* the status line's text, and each header, name lowercased */
        const char *p = (const char *)in.at + start, *he = (const char *)in.at + end;
        const char *eol = memchr(p, '\n', (size_t)(he - p));
        const char *reason = p + 12, *re = eol; /* past "HTTP/1.1 200" */
        while (re > reason && (re[-1] == '\r' || re[-1] == ' '))
            re--;
        while (reason < re && *reason == ' ')
            reason++;
        r->status_text = text_of(reason, reason < re ? (size_t)(re - reason) : 0);
        r->headers = kv_bytes_new();
        for (p = eol + 1; p < he;) {
            const char *e = memchr(p, '\n', (size_t)(he - p));
            if (!e)
                e = he;
            const char *colon = memchr(p, ':', (size_t)(e - p));
            if (colon && colon > p) {
                for (const char *k = p; k < colon; k++)
                    kv_bytes_push(&r->headers, (uint8_t)(*k >= 'A' && *k <= 'Z' ? *k + 32 : *k));
                kv_bytes_push(&r->headers, 0);
                const char *v = colon + 1, *ve = e;
                while (v < ve && (*v == ' ' || *v == '\t'))
                    v++;
                while (ve > v && (ve[-1] == '\r' || ve[-1] == ' ' || ve[-1] == '\t'))
                    ve--;
                for (const char *k = v; k < ve; k++)
                    if (*k)
                        kv_bytes_push(&r->headers, (uint8_t)*k);
                kv_bytes_push(&r->headers, 0);
            }
            p = e + 1;
        }
        size_t ll;
        const char *loc = header_in((const char *)in.at + start, he, "location", &ll);
        if (loc) {
            r->location = malloc(ll + 1);
            if (!r->location)
                abort();
            memcpy(r->location, loc, ll);
            r->location[ll] = 0;
        }
        r->body = kv_bytes_new();
        if (bodyless) {
        } else if (chunked) {
            if (dechunk(in.at + end, in.count - end, &r->body) != 1) {
                fail(error, "fetch: %s's chunked body %s", u->host, whole ? "is not one" : "ended before its last chunk");
                ok = false;
            }
        } else if (length >= 0) {
            if (in.count - end < (unsigned long long)length) {
                fail(error, "fetch: %s closed the connection before the body's %lld bytes came", u->host, length);
                ok = false;
            } else {
                kv_bytes_append(&r->body, in.at + end, (size_t)length);
            }
        } else {
            kv_bytes_append(&r->body, in.at + end, in.count - end);
        }
        if (!ok) {
            kv_string_free(&r->status_text);
            kv_bytes_free(&r->headers);
            kv_bytes_free(&r->body);
            free(r->location);
            r->location = NULL;
        }
    }
    kv_bytes_free(&in);
    return ok;
}

bool kfetch_get(const uint8_t *url, int64_t *status, kv_string *status_text, kv_string *final_url,
                int64_t *redirects, kv_bytes *headers, kv_bytes *body, kv_string *error) {
    char *current = copy_text((const char *)url);
    for (int hops = 0;; hops++) {
        url_t u;
        if (!parse_url(current, &u, error)) {
            free(current);
            return false;
        }
        response_t r = {0};
        if (!get_once(&u, &r, error)) {
            free(u.target);
            free(current);
            return false;
        }
        bool redirect = (r.status == 301 || r.status == 302 || r.status == 303 || r.status == 307 || r.status == 308) &&
                        r.location && r.location[0];
        if (redirect && hops < MAX_REDIRECTS) {
            char *next = resolve(&u, r.location);
            kv_string_free(&r.status_text);
            kv_bytes_free(&r.headers);
            kv_bytes_free(&r.body);
            free(r.location);
            free(u.target);
            free(current);
            current = next;
            continue;
        }
        if (redirect) {
            fail(error, "fetch: more than %d redirects, the last to %s", MAX_REDIRECTS, r.location);
            kv_string_free(&r.status_text);
            kv_bytes_free(&r.headers);
            kv_bytes_free(&r.body);
            free(r.location);
            free(u.target);
            free(current);
            return false;
        }
        char *final = url_text(&u);
        *status = r.status;
        kv_string_assign(status_text, r.status_text);
        kv_string_assign(final_url, text_of(final, strlen(final)));
        *redirects = hops;
        kv_bytes_assign(headers, r.headers);
        kv_bytes_assign(body, r.body);
        free(final);
        free(r.location);
        free(u.target);
        free(current);
        return true;
    }
}

bool kfetch_header(const kv_bytes *headers, int64_t i, kv_string *name, kv_string *value) {
    size_t p = 0;
    for (int64_t k = 0; k < i; k++) {
        for (int pair = 0; pair < 2; pair++) {
            const uint8_t *z = p < headers->count ? memchr(headers->at + p, 0, headers->count - p) : NULL;
            if (!z)
                return false;
            p = (size_t)(z - headers->at) + 1;
        }
    }
    if (p >= headers->count)
        return false;
    const uint8_t *z = memchr(headers->at + p, 0, headers->count - p);
    if (!z)
        return false;
    size_t q = (size_t)(z - headers->at) + 1;
    const uint8_t *z2 = q < headers->count ? memchr(headers->at + q, 0, headers->count - q) : NULL;
    if (!z2)
        return false;
    kv_string_assign(name, text_of(headers->at + p, (size_t)(z - (headers->at + p))));
    kv_string_assign(value, text_of(headers->at + q, (size_t)(z2 - (headers->at + q))));
    return true;
}
