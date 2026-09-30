/* util.c - allocation, strings, lists and diagnostics */
#include "kelvin.h"

#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

static const char *src_file, *src_text;

void *xmalloc(size_t n) {
    void *p = malloc(n ? n : 1);
    if (!p)
        fatal("out of memory");
    return p;
}

void *xcalloc(size_t n, size_t sz) {
    void *p = calloc(n ? n : 1, sz ? sz : 1);
    if (!p)
        fatal("out of memory");
    return p;
}

void *xrealloc(void *p, size_t n) {
    p = realloc(p, n ? n : 1);
    if (!p)
        fatal("out of memory");
    return p;
}

char *xstrndup(const char *s, size_t n) {
    char *p = xmalloc(n + 1);
    memcpy(p, s, n);
    p[n] = '\0';
    return p;
}

char *xstrdup(const char *s) { return xstrndup(s, strlen(s)); }

char *strfmt(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    char *p = xmalloc((size_t)n + 1);
    va_start(ap, fmt);
    vsnprintf(p, (size_t)n + 1, fmt, ap);
    va_end(ap);
    return p;
}

void list_push(List *l, void *x) {
    if (l->len == l->cap) {
        l->cap = l->cap ? l->cap * 2 : 8;
        l->data = xrealloc(l->data, (size_t)l->cap * sizeof(void *));
    }
    l->data[l->len++] = x;
}

void buf_putn(Buf *b, const char *s, size_t n) {
    if (b->len + n + 1 > b->cap) {
        while (b->len + n + 1 > b->cap)
            b->cap = b->cap ? b->cap * 2 : 256;
        b->buf = xrealloc(b->buf, b->cap);
    }
    memcpy(b->buf + b->len, s, n);
    b->len += n;
    b->buf[b->len] = '\0';
}

void buf_puts(Buf *b, const char *s) { buf_putn(b, s, strlen(s)); }

void buf_printf(Buf *b, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    char *tmp = xmalloc((size_t)n + 1);
    va_start(ap, fmt);
    vsnprintf(tmp, (size_t)n + 1, fmt, ap);
    va_end(ap);
    buf_putn(b, tmp, (size_t)n);
    free(tmp);
}

/* Quote bytes as a C string literal. Octal escapes are always three digits
   so a following digit can never extend them; '?' is escaped to defeat
   trigraphs. */
char *c_string_literal(const char *s, size_t n) {
    Buf b = {0};
    buf_puts(&b, "\"");
    for (size_t i = 0; i < n; i++) {
        unsigned char c = (unsigned char)s[i];
        switch (c) {
        case '"': buf_puts(&b, "\\\""); break;
        case '\\': buf_puts(&b, "\\\\"); break;
        case '?': buf_puts(&b, "\\?"); break;
        case '\n': buf_puts(&b, "\\n"); break;
        case '\t': buf_puts(&b, "\\t"); break;
        default:
            if (c >= 0x20 && c < 0x7f)
                buf_putn(&b, (const char *)&c, 1);
            else
                buf_printf(&b, "\\%03o", c);
        }
    }
    buf_puts(&b, "\"");
    return b.buf;
}

void set_source(const char *file, const char *src) {
    src_file = file;
    src_text = src;
}

_Noreturn void fatal(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "kelvinc: ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(1);
}

static void show_line(Pos p) {
    if (!src_text || !p.file || !src_file || strcmp(p.file, src_file) != 0)
        return;
    const char *s = src_text;
    for (int line = 1; line < p.line && *s; s++)
        if (*s == '\n')
            line++;
    const char *e = s;
    while (*e && *e != '\n')
        e++;
    fprintf(stderr, "  %.*s\n  ", (int)(e - s), s);
    for (int i = 1; i < p.col; i++)
        fputc(s[i - 1] == '\t' ? '\t' : ' ', stderr);
    fprintf(stderr, "^\n");
}

_Noreturn void error_at(Pos p, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "%s:%d:%d: error: ", p.file, p.line, p.col);
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    show_line(p);
    exit(1);
}
