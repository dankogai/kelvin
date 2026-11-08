/* fetch.c - the engine of #import <fetch> (#482, #483, #486, #487): JS's
   fetch(url, init) over HTTP/1.1, of our own over sockets: a method,
   headers and a body, following redirects as JS's does, up to 20, or not,
   within a timeout, and ended at once by an abort. HTTPS is
   OpenSSL's where libkfetch is built with HAS_SSL=1, which defines
   KV_HAS_SSL; else an https URL is an error that says so.
   Each request says Connection: close and Accept-Encoding: identity, so a
   response ends where its Content-Length, its last chunk or the connection
   does, and its body is as sent. */
/* POSIX under -std=c11, which hides getaddrinfo and its kin, as os.c has it */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#elif !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)
#define _XOPEN_SOURCE 700
#define _DEFAULT_SOURCE 1
#define _GNU_SOURCE 1 /* fopencookie, glibc's and musl's, for a body that streams (#488) */
#endif
#include "kelvin_prelude.h"
#include "kfetch.h"
#include "kIO.h" /* the IO a body that streams is read by (#488) */

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <netdb.h>
#include <netinet/in.h>
#include <poll.h>
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

/* SILENCE_SECONDS: how long a wait may be, to connect or for a byte, where
   the caller gives no timeout (#486) */
enum { MAX_REDIRECTS = 20, SILENCE_SECONDS = 60 };

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

/* ---------- aborts (#487) ---------- */

/* An AbortController's state, by its signal's id, 1 up, 0 for none: whether
   it was aborted, why, and the socket of the fetch it watches, which abort()
   shuts down to wake a read or a write blocked on it. Kept for the
   program's life, as a Kelvin struct has no destructor, and reached by
   index under the lock alone, as the table moves when it grows. */
typedef struct {
    bool aborted;
    char *reason; /* malloc'd, or NULL for none */
    int fd;       /* the watched fetch's socket, or -1 */
} abort_t;
static pthread_mutex_t aborts_lock = PTHREAD_MUTEX_INITIALIZER;
static abort_t *aborts;
static size_t aborts_count, aborts_room;

/* the table, freed as the program exits, so that a leak checker counts
   nothing live then */
static void aborts_free(void) {
    pthread_mutex_lock(&aborts_lock);
    for (size_t i = 0; i < aborts_count; i++)
        free(aborts[i].reason);
    free(aborts);
    aborts = NULL;
    aborts_count = aborts_room = 0;
    pthread_mutex_unlock(&aborts_lock);
}

int64_t kfetch_abort_new(void) {
    pthread_mutex_lock(&aborts_lock);
    if (!aborts_room)
        atexit(aborts_free);
    if (aborts_count == aborts_room) {
        size_t room = aborts_room ? aborts_room * 2 : 16;
        abort_t *grown = realloc(aborts, room * sizeof *grown);
        if (!grown)
            abort();
        aborts = grown;
        aborts_room = room;
    }
    aborts[aborts_count] = (abort_t){false, NULL, -1};
    int64_t id = (int64_t)++aborts_count;
    pthread_mutex_unlock(&aborts_lock);
    return id;
}

/* the entry of id, under the lock, or NULL for none */
static abort_t *abort_of(int64_t id) {
    return id >= 1 && (uint64_t)id <= aborts_count ? &aborts[id - 1] : NULL;
}

void kfetch_abort(int64_t id, const uint8_t *reason) {
    pthread_mutex_lock(&aborts_lock);
    abort_t *a = abort_of(id);
    if (a && !a->aborted) { /* the first reason stays, as JS's */
        a->aborted = true;
        if (reason && *reason) {
            size_t n = strlen((const char *)reason) + 1;
            a->reason = malloc(n);
            if (!a->reason)
                abort();
            memcpy(a->reason, reason, n);
        }
        if (a->fd >= 0)
            shutdown(a->fd, SHUT_RDWR);
    }
    pthread_mutex_unlock(&aborts_lock);
}

bool kfetch_aborted(int64_t id) {
    pthread_mutex_lock(&aborts_lock);
    abort_t *a = abort_of(id);
    bool aborted = a && a->aborted;
    pthread_mutex_unlock(&aborts_lock);
    return aborted;
}

/* the socket that id's abort shuts down, -1 for none, before it is closed,
   so that a number the system gives again is never shut down; whether it
   was aborted already */
static bool abort_watch(int64_t id, int fd) {
    pthread_mutex_lock(&aborts_lock);
    abort_t *a = abort_of(id);
    bool aborted = false;
    if (a) {
        a->fd = a->aborted ? -1 : fd;
        aborted = a->aborted;
    }
    pthread_mutex_unlock(&aborts_lock);
    return aborted;
}

static void aborted_error(int64_t id, kv_string *error) {
    pthread_mutex_lock(&aborts_lock);
    abort_t *a = abort_of(id);
    char reason[512];
    snprintf(reason, sizeof reason, "%s", a && a->reason ? a->reason : "");
    pthread_mutex_unlock(&aborts_lock);
    if (reason[0])
        fail(error, "fetch: aborted: %s", reason);
    else
        fail(error, "fetch: aborted");
}

/* ---------- connections ---------- */

typedef struct {
    int fd;
    double deadline; /* the caller's, by now_seconds, or 0 for none (#486) */
    int64_t signal;  /* its AbortSignal's id, 0 for none (#487) */
    double timeout;  /* the seconds it was given as, for the Error */
#ifdef KV_HAS_SSL
    SSL_CTX *ctx;
    SSL *ssl;
#endif
} conn_t;

static void conn_close(conn_t *c) {
    abort_watch(c->signal, -1); /* before the number is free again */
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

/* seconds by a clock that only goes forward */
static double now_seconds(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}

/* how long the next wait may be: up to the caller's deadline, or else
   SILENCE_SECONDS; 0 or less once the deadline has passed */
static double wait_left(const conn_t *c) {
    return c->deadline > 0 ? c->deadline - now_seconds() : SILENCE_SECONDS;
}

static bool passed(const conn_t *c) { return c->deadline > 0 && now_seconds() >= c->deadline; }

/* the seconds as Kelvin prints an f64, every digit, 0.29999999999999999 */
static const char *seconds_text(double s, uint8_t *buf) { return (const char *)kv_cstr_f64(s, buf); }

static void timed_out(const conn_t *c, kv_string *error) {
    uint8_t buf[KV_CSTR_SCALAR];
    fail(error, "fetch: the timeout of %s seconds passed", seconds_text(c->timeout, buf));
}

/* the next waits of the socket, a read and a write, bounded by what is left;
   false, with error, where nothing is */
static bool bound_waits(const conn_t *c, kv_string *error) {
    if (kfetch_aborted(c->signal)) {
        aborted_error(c->signal, error);
        return false;
    }
    double left = wait_left(c);
    if (left <= 0) {
        timed_out(c, error);
        return false;
    }
    if (left < 0.001)
        left = 0.001; /* a timeval of 0 is no bound at all */
    struct timeval tv = {(time_t)left, (int)((left - (double)(time_t)left) * 1e6)};
    setsockopt(c->fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
    setsockopt(c->fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);
    return true;
}

/* connect within left seconds: without blocking, and then poll for it;
   0, or -1 with errno, ETIMEDOUT where the time ran out */
static int connect_within(int fd, const struct sockaddr *a, socklen_t n, double left, int64_t signal) {
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    int r = connect(fd, a, n);
    if (r < 0 && errno == EINPROGRESS) {
        double end = now_seconds() + left;
        for (;;) {
            double ms = (end - now_seconds()) * 1000;
            struct pollfd p = {fd, POLLOUT, 0};
            if (kfetch_aborted(signal)) { /* seen within a slice of 0.1 s (#487) */
                errno = ECANCELED;
                r = -1;
                break;
            }
            r = ms > 0 ? poll(&p, 1, ms > 100 ? 100 : (int)ms + 1) : 0;
            if ((r < 0 && errno == EINTR) || (r == 0 && ms > 100))
                continue;
            break;
        }
        if (r == 0) {
            errno = ETIMEDOUT;
            r = -1;
        } else if (r > 0) {
            int e = 0;
            socklen_t len = sizeof e;
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &e, &len);
            r = e ? -1 : 0;
            if (e)
                errno = e;
        }
    }
    int saved = errno;
    fcntl(fd, F_SETFL, flags);
    errno = saved;
    return r;
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
        X509_VERIFY_PARAM_set1_host(SSL_get0_param(c->ssl), u->host, 0); /* SSL_set1_host, deprecated in OpenSSL 4 */
    }
    if (!bound_waits(c, error))
        return false;
    if (SSL_connect(c->ssl) != 1) {
        long v = SSL_get_verify_result(c->ssl);
        if (kfetch_aborted(c->signal))
            aborted_error(c->signal, error);
        else if (passed(c))
            timed_out(c, error);
        else if (v != X509_V_OK)
            fail(error, "fetch: the certificate of %s is not trusted: %s", u->host, X509_verify_cert_error_string(v));
        else
            fail(error, "fetch: TLS with %s failed: %s", u->host, ssl_reason("the handshake did not finish"));
        return false;
    }
    return true;
}
#endif

static bool conn_open(conn_t *c, const url_t *u, double deadline, double timeout, int64_t signal,
                      kv_string *error) {
    c->fd = -1;
    c->deadline = deadline;
    c->timeout = timeout;
    c->signal = signal;
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
    if (passed(c)) { /* the lookup counts, though nothing cuts it short */
        freeaddrinfo(res);
        timed_out(c, error);
        return false;
    }
    if (kfetch_aborted(signal)) {
        freeaddrinfo(res);
        aborted_error(signal, error);
        return false;
    }
    int err = 0;
    for (struct addrinfo *a = res; a; a = a->ai_next) {
        int fd = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
        if (fd < 0) {
            err = errno;
            continue;
        }
#ifdef SO_NOSIGPIPE
        int one = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof one);
#endif
        if (abort_watch(signal, fd)) {
            close(fd);
            break;
        }
        double left = wait_left(c);
        if (left > 0 && connect_within(fd, a->ai_addr, a->ai_addrlen, left, signal) == 0) {
            c->fd = fd;
            break;
        }
        err = left > 0 ? errno : ETIMEDOUT;
        abort_watch(signal, -1);
        close(fd);
        if (passed(c) || kfetch_aborted(signal))
            break;
    }
    freeaddrinfo(res);
    if (c->fd >= 0 && kfetch_aborted(signal)) {
        aborted_error(signal, error);
        return false;
    }
    if (c->fd < 0 && kfetch_aborted(signal)) {
        aborted_error(signal, error);
        return false;
    }
    if (c->fd < 0 && passed(c)) {
        timed_out(c, error);
        return false;
    }
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
        if (!bound_waits(c, error)) {
            ok = false;
            break;
        }
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
            if (kfetch_aborted(c->signal))
                aborted_error(c->signal, error);
            else if (passed(c))
                timed_out(c, error);
            else
                fail(error, "fetch: the request could not be sent: %s",
                     errno == EAGAIN || errno == EWOULDBLOCK ? "no room in 60 seconds" : strerror(errno));
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
        if (!bound_waits(c, error))
            return -1;
#ifdef KV_HAS_SSL
        if (c->ssl) {
            int r = SSL_read(c->ssl, buf, (int)n);
            if (r > 0)
                return r;
            if (kfetch_aborted(c->signal)) { /* a shutdown by abort() ends no body (#487) */
                aborted_error(c->signal, error);
                return -1;
            }
            int e = SSL_get_error(c->ssl, r);
            if (e == SSL_ERROR_ZERO_RETURN)
                return 0;
            if (e == SSL_ERROR_SYSCALL && !ERR_peek_error() && (r == 0 || errno == 0))
                return 0; /* closed without close_notify */
            if (passed(c))
                timed_out(c, error);
            else if (e == SSL_ERROR_SYSCALL && (errno == EAGAIN || errno == EWOULDBLOCK))
                fail(error, "fetch: reading the response failed: no answer in 60 seconds");
            else
                fail(error, "fetch: reading over TLS failed: %s", ssl_reason(strerror(errno)));
            return -1;
        }
#endif
        long r = (long)recv(c->fd, buf, n, 0);
        if (r <= 0 && kfetch_aborted(c->signal)) { /* a shutdown by abort() ends no body (#487) */
            aborted_error(c->signal, error);
            return -1;
        }
        if (r >= 0)
            return r;
        if (errno == EINTR)
            continue;
        if (passed(c)) {
            timed_out(c, error);
            return -1;
        }
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

/* ---------- a body that streams (#488) ---------- */

/* the body of a response, read as it comes through a FILE * of its own,
   fopencookie's or funopen's, which an IO holds: the connection, the bytes
   read past the headers and not yet given, and how the body ends */
enum { STREAM_NONE, STREAM_LENGTH, STREAM_CHUNKED, STREAM_CLOSE };
enum { CHUNK_SIZE, CHUNK_DATA, CHUNK_END, CHUNK_TRAILER };
typedef struct stream_s {
    conn_t c;
    kv_bytes raw;            /* bytes from the connection, not yet given, from at */
    size_t at;
    int mode, chunk;         /* STREAM_*, and CHUNK_* where it is chunked */
    unsigned long long left; /* of the body, by its length, or of the chunk */
    bool done;
    char *failure;           /* what went wrong, malloc'd, for res.streamError, NULL for none */
    char host[256];
    FILE *fp;
    struct stream_s *next;   /* the streams open, for kfetch_stream_error */
} stream_t;
static pthread_mutex_t streams_lock = PTHREAD_MUTEX_INITIALIZER;
static stream_t *streams;

static void stream_fail(stream_t *s, const char *message) {
    if (!s->failure) {
        size_t n = strlen(message) + 1;
        s->failure = malloc(n);
        if (!s->failure)
            abort();
        memcpy(s->failure, message, n);
    }
    errno = EIO;
}

/* more bytes from the connection into raw: their count, 0 at its end, -1
   where it failed, with the stream's failure */
static long stream_fill(stream_t *s) {
    if (s->at == s->raw.count) {
        s->raw.count = 0;
        s->at = 0;
    }
    char buf[16384];
    kv_string error = kv_string_new();
    long got = conn_read(&s->c, buf, sizeof buf, &error);
    if (got < 0) {
        char message[1024];
        snprintf(message, sizeof message, "%.*s", (int)error.b.count, (const char *)error.b.at);
        stream_fail(s, message);
    } else if (got > 0) {
        kv_bytes_append(&s->raw, buf, (size_t)got);
    }
    kv_string_free(&error);
    return got;
}

/* the offset just past the next line in raw from at, its length in *len
   without the line break; 0 where it has not all come yet */
static size_t raw_line(const stream_t *s, size_t *len) {
    const uint8_t *nl = s->at < s->raw.count ? memchr(s->raw.at + s->at, '\n', s->raw.count - s->at) : NULL;
    if (!nl)
        return 0;
    size_t end = (size_t)(nl - s->raw.at);
    *len = end - s->at - (end > s->at && s->raw.at[end - 1] == '\r');
    return end + 1;
}

/* up to n bytes of the body into buf: their count, 0 at its end, -1 where
   it failed, as a read of a FILE * is */
static long stream_read(stream_t *s, char *buf, size_t n) {
    if (s->failure) {
        errno = EIO;
        return -1;
    }
    while (!s->done) {
        size_t have = s->raw.count - s->at;
        if (s->mode == STREAM_NONE) {
            s->done = true;
        } else if (s->mode == STREAM_CLOSE || (s->mode == STREAM_CHUNKED && s->chunk == CHUNK_DATA) ||
                   s->mode == STREAM_LENGTH) {
            bool counted = s->mode != STREAM_CLOSE;
            if (counted && !s->left) {
                if (s->mode == STREAM_LENGTH)
                    s->done = true;
                else
                    s->chunk = CHUNK_END;
                continue;
            }
            if (have) {
                size_t take = have < n ? have : n;
                if (counted && take > s->left)
                    take = (size_t)s->left;
                memcpy(buf, s->raw.at + s->at, take);
                s->at += take;
                if (counted)
                    s->left -= take;
                return (long)take;
            }
            long got = stream_fill(s);
            if (got < 0)
                return -1;
            if (!got) {
                if (s->mode == STREAM_CLOSE) {
                    s->done = true;
                } else {
                    char message[512];
                    if (s->mode == STREAM_LENGTH)
                        snprintf(message, sizeof message, "fetch: %s closed the connection before the body's end, %llu bytes short",
                                 s->host, s->left);
                    else
                        snprintf(message, sizeof message, "fetch: %s's chunked body ended before its last chunk", s->host);
                    stream_fail(s, message);
                    return -1;
                }
            }
        } else { /* a chunk's size, the line after its data, or a trailer */
            size_t len = 0, next = raw_line(s, &len);
            if (!next) {
                long got = stream_fill(s);
                if (got < 0)
                    return -1;
                if (!got) {
                    char message[512];
                    snprintf(message, sizeof message, "fetch: %s's chunked body ended before its last chunk", s->host);
                    stream_fail(s, message);
                    return -1;
                }
                continue;
            }
            const uint8_t *line = s->raw.at + s->at;
            s->at = next;
            if (s->chunk == CHUNK_SIZE) {
                unsigned long long size = 0;
                size_t digits = 0;
                for (; digits < len; digits++) {
                    uint8_t c = line[digits];
                    int d = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
                    if (d < 0 || size > (1ull << 56))
                        break;
                    size = size * 16 + (unsigned)d;
                }
                if (!digits) {
                    char message[512];
                    snprintf(message, sizeof message, "fetch: %s's chunked body is not one", s->host);
                    stream_fail(s, message);
                    return -1;
                }
                s->left = size;
                s->chunk = size ? CHUNK_DATA : CHUNK_TRAILER;
            } else if (s->chunk == CHUNK_END) {
                s->chunk = CHUNK_SIZE;
            } else if (!len) { /* the blank line after the trailers */
                s->done = true;
            }
        }
    }
    return 0;
}

static void stream_free(stream_t *s) {
    conn_close(&s->c);
    kv_bytes_free(&s->raw);
    free(s->failure);
    free(s);
}

/* the FILE *'s close: the stream no longer open, and its connection closed */
static int stream_close(void *cookie) {
    stream_t *s = cookie;
    pthread_mutex_lock(&streams_lock);
    for (stream_t **p = &streams; *p; p = &(*p)->next)
        if (*p == s) {
            *p = s->next;
            break;
        }
    pthread_mutex_unlock(&streams_lock);
    stream_free(s);
    return 0;
}

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__DragonFly__)
static int stream_read_fn(void *cookie, char *buf, int n) { return (int)stream_read(cookie, buf, n > 0 ? (size_t)n : 0); }
static FILE *stream_file(stream_t *s) { return funopen(s, stream_read_fn, NULL, NULL, stream_close); }
#else
static ssize_t stream_read_fn(void *cookie, char *buf, size_t n) { return stream_read(cookie, buf, n); }
static FILE *stream_file(stream_t *s) {
    cookie_io_functions_t io = {.read = stream_read_fn, .write = NULL, .seek = NULL, .close = stream_close};
    return fopencookie(s, "r", io);
}
#endif

/* the IO of a stream, registered so that kfetch_stream_error finds it; an
   IO of a file, kind 1, which fclose closes, and so the stream */
static void stream_open(stream_t *s, kv_io *io) {
    s->fp = stream_file(s);
    if (!s->fp)
        abort();
    pthread_mutex_lock(&streams_lock);
    s->next = streams;
    streams = s;
    pthread_mutex_unlock(&streams_lock);
    kv_io f = {0};
    f.status = f.signal = -1;
    f.fp = s->fp;
    f.kind = 1;
    *io = f;
}

bool kfetch_stream_error(const kv_io *io, kv_string *message) {
    bool failed = false;
    pthread_mutex_lock(&streams_lock);
    for (stream_t *s = streams; s; s = s->next)
        if (io->fp && s->fp == io->fp && s->failure) {
            kv_string_assign(message, text_of(s->failure, strlen(s->failure)));
            failed = true;
        }
    pthread_mutex_unlock(&streams_lock);
    return failed;
}

void kfetch_stream_rest(const kv_io *io, kv_bytes *out) {
    if (!io->fp)
        return;
    uint8_t buf[16384];
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, (FILE *)io->fp)) > 0)
        kv_bytes_append(out, buf, n);
}

typedef struct {
    int status;
    kv_string status_text;
    kv_bytes headers; /* name\0value\0 ... */
    kv_bytes body;
    char *location;   /* of a redirect, malloc'd */
    stream_t *stream; /* where the body streams (#488), its connection still open; else NULL */
} response_t;

/* header pair i of h, name\0value\0 ..., or false past the last */
static bool pair_at(const kv_bytes *h, size_t *at, const char **name, const char **value) {
    if (*at >= h->count)
        return false;
    *name = (const char *)h->at + *at;
    *at += strlen(*name) + 1;
    if (*at >= h->count)
        return false;
    *value = (const char *)h->at + *at;
    *at += strlen(*value) + 1;
    return true;
}

static bool has_pair(const kv_bytes *h, const char *name) {
    size_t at = 0;
    const char *k, *v;
    while (pair_at(h, &at, &k, &v))
        if (!strcasecmp(k, name))
            return true;
    return false;
}

/* h without the pairs named in names, a NULL-ended list */
static void drop_pairs(kv_bytes *h, const char *const *names) {
    kv_bytes kept = kv_bytes_new();
    size_t at = 0;
    const char *k, *v;
    while (pair_at(h, &at, &k, &v)) {
        bool drop = false;
        for (int i = 0; names[i]; i++)
            drop = drop || !strcasecmp(k, names[i]);
        if (!drop) {
            kv_bytes_append(&kept, k, strlen(k) + 1);
            kv_bytes_append(&kept, v, strlen(v) + 1);
        }
    }
    kv_bytes_assign(h, kept);
}

static void put(kv_bytes *b, const char *s) { kv_bytes_append(b, s, strlen(s)); }

/* one request of u: method, the caller's header pairs, then fetch's own
   where the caller gave none, and the body; the response, or false with
   error */
static bool request_once(const url_t *u, const char *method, const kv_bytes *headers, const kv_bytes *body,
                         double deadline, double timeout, int64_t signal, bool stream, response_t *r,
                         kv_string *error) {
    conn_t c;
    if (!conn_open(&c, u, deadline, timeout, signal, error)) {
        conn_close(&c);
        return false;
    }
    bool v6 = strchr(u->host, ':') != NULL;
    kv_bytes q = kv_bytes_new();
    put(&q, method);
    put(&q, " ");
    put(&q, u->target);
    put(&q, " HTTP/1.1\r\nHost: ");
    put(&q, v6 ? "[" : "");
    put(&q, u->host);
    put(&q, v6 ? "]" : "");
    if (u->port_given) {
        put(&q, ":");
        put(&q, u->port);
    }
    put(&q, "\r\n");
    size_t at = 0;
    const char *k, *v;
    while (pair_at(headers, &at, &k, &v)) {
        put(&q, k);
        put(&q, ": ");
        put(&q, v);
        put(&q, "\r\n");
    }
    if (!has_pair(headers, "user-agent"))
        put(&q, "User-Agent: Kelvin-fetch\r\n");
    if (!has_pair(headers, "accept"))
        put(&q, "Accept: */*\r\n");
    if (!has_pair(headers, "accept-encoding"))
        put(&q, "Accept-Encoding: identity\r\n");
    if (body->count || !strcmp(method, "POST") || !strcmp(method, "PUT")) { /* a POST or PUT of none says 0, as JS's */
        char len[32];
        snprintf(len, sizeof len, "Content-Length: %zu\r\n", body->count);
        put(&q, len);
    }
    put(&q, "Connection: close\r\n\r\n");
    if (body->count)
        kv_bytes_append(&q, body->at, body->count);
    bool sent = conn_write(&c, (const char *)q.at, q.count, error);
    kv_bytes_free(&q);
    if (!sent) {
        conn_close(&c);
        return false;
    }
    bool head = !strcmp(method, "HEAD");
    kv_bytes in = kv_bytes_new();
    char buf[16384];
    size_t start = 0, end = 0;  /* the final header block, past any 1xx */
    long long length = -1;      /* its Content-Length */
    bool chunked = false, bodyless = false, ok = true, whole = false;
    for (;;) {
        if (end && stream) /* the body is read as it is asked for (#488) */
            break;
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
            bodyless = head || status == 204 || status == 304; /* a HEAD's answer has none, whatever it says */
        }
        if (!ok)
            break;
    }
    if (!ok || !end || !stream)
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
        if (stream) { /* the connection, and what came past the headers, go to the stream */
            stream_t *s = calloc(1, sizeof *s);
            if (!s)
                abort();
            s->c = c;
            s->raw = kv_bytes_new();
            kv_bytes_append(&s->raw, in.at + end, in.count - end);
            s->mode = bodyless ? STREAM_NONE : chunked ? STREAM_CHUNKED : length >= 0 ? STREAM_LENGTH : STREAM_CLOSE;
            s->chunk = CHUNK_SIZE;
            s->left = length >= 0 ? (unsigned long long)length : 0;
            snprintf(s->host, sizeof s->host, "%s", u->host);
            r->stream = s;
        } else if (bodyless) {
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

/* whether c may be in a token, HTTP's word for a method or a header name */
static bool token_char(unsigned char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || (c && strchr("!#$%&'*+-.^_`|~", c));
}

static bool is_token(const char *s) {
    if (!*s)
        return false;
    for (; *s; s++)
        if (!token_char((unsigned char)*s))
            return false;
    return true;
}

/* the method as it is sent: GET where none is given; DELETE, GET, HEAD,
   OPTIONS, POST and PUT in capitals however they are written, as JS's
   fetch normalizes them, the rest as written; NULL, with error, where it
   is not a token, or is CONNECT, TRACE or TRACK, which JS's refuses */
static char *method_of(const char *m, kv_string *error) {
    if (!*m)
        return copy_text("GET");
    if (!is_token(m)) {
        fail(error, "fetch: a method is a word of letters, digits and !#$%%&'*+-.^_`|~, and this is %s", m);
        return NULL;
    }
    static const char *const forbidden[] = {"CONNECT", "TRACE", "TRACK", NULL};
    for (int i = 0; forbidden[i]; i++)
        if (!strcasecmp(m, forbidden[i])) {
            fail(error, "fetch: the method %s is not fetch's to send", m);
            return NULL;
        }
    static const char *const normal[] = {"DELETE", "GET", "HEAD", "OPTIONS", "POST", "PUT", NULL};
    for (int i = 0; normal[i]; i++)
        if (!strcasecmp(m, normal[i]))
            return copy_text(normal[i]);
    return copy_text(m);
}

/* the origin of u, scheme, host and port, as a redirect compares it */
static bool same_origin(const url_t *a, const url_t *b) {
    return a->https == b->https && !strcasecmp(a->host, b->host) && !strcmp(a->port, b->port);
}

enum { REDIRECT_FOLLOW, REDIRECT_MANUAL, REDIRECT_ERROR }; /* RequestInit's redirect, its enum's values */

bool kfetch_request(const uint8_t *url, const uint8_t *method_given, const kv_bytes *headers_given,
                    const kv_bytes *body_given, int64_t redirect, double timeout, int64_t signal, bool stream,
                    int64_t *status, kv_string *status_text, kv_string *final_url, int64_t *redirects,
                    kv_bytes *headers, kv_bytes *body, kv_io *streamed, kv_string *error) {
    if (kfetch_aborted(signal)) { /* a signal aborted already fails at once, as JS's (#487) */
        aborted_error(signal, error);
        return false;
    }
    /* the caller's timeout, in seconds over the whole request, redirects
       and all (#486): 0, or an infinity, for none */
    if (isnan(timeout) || timeout < 0) {
        uint8_t buf[KV_CSTR_SCALAR];
        fail(error, "fetch: a timeout is a number of seconds, 0 for none, and this is %s", seconds_text(timeout, buf));
        return false;
    }
    double deadline = timeout > 0 && isfinite(timeout) ? now_seconds() + timeout : 0;
    /* the caller's headers: names tokens, values on one line, and none
       that fetch sends itself, as the framing of the request is its own */
    static const char *const own[] = {"host", "content-length", "connection", "transfer-encoding", "keep-alive",
                                      "upgrade", "te", "trailer", NULL};
    size_t at = 0;
    const char *k, *v;
    while (pair_at(headers_given, &at, &k, &v)) {
        if (!is_token(k)) {
            fail(error, "fetch: a header's name is a word of letters, digits and !#$%%&'*+-.^_`|~, and this is '%s'", k);
            return false;
        }
        if (strpbrk(v, "\r\n")) {
            fail(error, "fetch: the header '%s' has a line break in its value", k);
            return false;
        }
        for (int i = 0; own[i]; i++)
            if (!strcasecmp(k, own[i])) {
                fail(error, "fetch: the header '%s' is fetch's own to send", k);
                return false;
            }
    }
    char *method = method_of((const char *)method_given, error);
    if (!method)
        return false;
    if (body_given->count && (!strcmp(method, "GET") || !strcmp(method, "HEAD"))) {
        fail(error, "fetch: a %s request has no body", method);
        free(method);
        return false;
    }
    kv_bytes hs = kv_bytes_copy(headers_given), bs = kv_bytes_copy(body_given);
    char *current = copy_text((const char *)url);
    bool ok = false;
    for (int hops = 0;; hops++) {
        url_t u;
        if (!parse_url(current, &u, error))
            break;
        response_t r = {0};
        if (!request_once(&u, method, &hs, &bs, deadline, timeout, signal, stream, &r, error)) {
            free(u.target);
            break;
        }
        bool moved = (r.status == 301 || r.status == 302 || r.status == 303 || r.status == 307 || r.status == 308) &&
                     r.location && r.location[0] && redirect != REDIRECT_MANUAL;
        if (moved && redirect == REDIRECT_ERROR) {
            char *here = url_text(&u);
            fail(error, "fetch: %s redirected to %s, and the redirect was to be an error", here, r.location);
            free(here);
        } else if (moved && hops >= MAX_REDIRECTS) {
            fail(error, "fetch: more than %d redirects, the last to %s", MAX_REDIRECTS, r.location);
        } else if (moved) {
            /* JS's: a 303 asks again by GET, as a 301 or 302 does a POST,
               without the body and the headers about it; another origin
               is not sent the Authorization */
            char *next = resolve(&u, r.location);
            if ((r.status == 303 && strcmp(method, "GET") && strcmp(method, "HEAD")) ||
                ((r.status == 301 || r.status == 302) && !strcmp(method, "POST"))) {
                free(method);
                method = copy_text("GET");
                kv_bytes_clear(&bs);
                static const char *const about_body[] = {"content-type", "content-encoding", "content-language",
                                                         "content-location", NULL};
                drop_pairs(&hs, about_body);
            }
            url_t to;
            kv_string ignored = kv_string_new();
            if (parse_url(next, &to, &ignored)) {
                if (!same_origin(&u, &to)) {
                    static const char *const credentials[] = {"authorization", NULL};
                    drop_pairs(&hs, credentials);
                }
                free(to.target);
            }
            kv_string_free(&ignored);
            kv_string_free(&r.status_text);
            kv_bytes_free(&r.headers);
            kv_bytes_free(&r.body);
            if (r.stream) /* a redirect's body, never read */
                stream_free(r.stream);
            free(r.location);
            free(u.target);
            free(current);
            current = next;
            continue;
        } else {
            char *final = url_text(&u);
            *status = r.status;
            kv_string_assign(status_text, r.status_text);
            kv_string_assign(final_url, text_of(final, strlen(final)));
            *redirects = hops;
            kv_bytes_assign(headers, r.headers);
            kv_bytes_assign(body, r.body);
            if (r.stream) /* the body, as it comes, by an IO (#488) */
                stream_open(r.stream, streamed);
            free(final);
            free(r.location);
            free(u.target);
            ok = true;
            break;
        }
        kv_string_free(&r.status_text);
        kv_bytes_free(&r.headers);
        kv_bytes_free(&r.body);
        if (r.stream) /* a redirect's, made an Error */
            stream_free(r.stream);
        free(r.location);
        free(u.target);
        break;
    }
    free(current);
    free(method);
    kv_bytes_free(&hs);
    kv_bytes_free(&bs);
    return ok;
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
