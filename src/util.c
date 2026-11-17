/* util.c - allocation, strings, lists and diagnostics */
#include "kelvin.h"

#include <ctype.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

/* the text of each source file, for showing the line of a message */
static List src_files, src_texts;

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

void set_source(const char *file, const char *src) {
    list_push(&src_files, (void *)file);
    list_push(&src_texts, (void *)src);
}

const char *source_text_of(const char *file) {
    for (int i = 0; file && i < src_files.len; i++)
        if (!strcmp(file, src_files.data[i]))
            return src_texts.data[i];
    return NULL;
}

/* A file of the prelude (#600): UnicodeData, RegExp, BigInt or math, the
   source or its header, by its name. What it declares at its top level is
   what Kelvin.name names, and a program's own of that name hides bare */
bool prelude_file(const char *path) {
    static const char *files[] = {"UnicodeData.k", "UnicodeData.kh", "RegExp.k", "RegExp.kh",
                                  "BigInt.k",      "BigInt.kh",      "math.k",   "math.kh",   NULL};
    const char *slash = path ? strrchr(path, '/') : NULL;
    const char *base = slash ? slash + 1 : path;
    for (int i = 0; base && files[i]; i++)
        if (!strcmp(base, files[i]))
            return true;
    return false;
}

/* A message as it is shown: a type of the program's own that has the name
   of one of the prelude's is _kv_own_T in the tokens and in C (#600), and
   T in what kelvinc says of it; the prelude's, where the program has such
   a type, is Kelvin.T, as the program writes each */
List kv_own_names; /* char *: those names, which main.c gives */

static bool name_char(char c) { return isalnum((unsigned char)c) || c == '_' || (unsigned char)c >= 0x80; }

/* s as it is shown, or written in a library's header */
char *kv_shown(const char *s) {
    Buf b = {0};
    buf_puts(&b, "");
    for (const char *at = s; *at;) {
        if (!strncmp(at, KV_OWN, strlen(KV_OWN))) { /* the program's own: its name */
            at += strlen(KV_OWN);
            while (name_char(*at))
                buf_printf(&b, "%c", *at++);
            continue;
        }
        size_t len = 0;
        for (int i = 0; !len && i < kv_own_names.len && (at == s || (!name_char(at[-1]) && at[-1] != '.')); i++) {
            size_t k = strlen(kv_own_names.data[i]);
            if (!strncmp(at, kv_own_names.data[i], k) && !name_char(at[k]))
                len = k;
        }
        if (len) { /* the prelude's of that name */
            buf_printf(&b, "Kelvin.%.*s", (int)len, at);
            at += len;
            continue;
        }
        buf_printf(&b, "%c", *at++);
    }
    return b.buf;
}

static void show_message(const char *fmt, va_list ap) {
    va_list again;
    va_copy(again, ap);
    int n = vsnprintf(NULL, 0, fmt, again);
    va_end(again);
    if (n < 0)
        return;
    char *s = xmalloc((size_t)n + 1);
    vsnprintf(s, (size_t)n + 1, fmt, ap);
    fputs(kv_shown(s), stderr);
    free(s);
}

_Noreturn void fatal(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "kelvinc: ");
    show_message(fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(1);
}

static void show_line(Pos p) {
    const char *src_text = NULL;
    for (int i = 0; p.file && i < src_files.len; i++)
        if (!strcmp(p.file, src_files.data[i]))
            src_text = src_texts.data[i];
    if (!src_text)
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
    show_message(fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    show_line(p);
    exit(1);
}
