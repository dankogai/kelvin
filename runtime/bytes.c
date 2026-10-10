/* bytes.c - Bytes (#54): the first owner, a growable array of u8 on the
   heap. at[count] is always a NUL that count does not count, so cstr is
   a borrow; an empty Bytes has at == NULL and nothing to free. Out of
   memory and an index out of range abort. */
#include "kelvin_prelude.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void kv_bytes_fail(const char *what) {
    fflush(stdout);
    fprintf(stderr, "kelvin: %s\n", what);
    abort();
}

/* for every Array<T> (#57), instantiated in the program's C */
void kv_array_fail(const char *what) { kv_bytes_fail(what); }

void kv_array_range(size_t i, size_t count) {
    char msg[96];
    snprintf(msg, sizeof msg, "index %zu is out of range: the Array has %zu", i, count);
    kv_bytes_fail(msg);
}

/* an enum with values (#61): a case read that is not the current one */
void kv_case_fail(const char *type, const char *want, const char *have) {
    char msg[160];
    snprintf(msg, sizeof msg, "case '%s' of %s is not current: it is '%s'", want, type, have);
    kv_bytes_fail(msg);
}

/* a slice (#68): lo..<hi within count, else the program ends */
void kv_slice_range(size_t lo, size_t hi, size_t count, const char *what) {
    char msg[128];
    snprintf(msg, sizeof msg, "range %zu..<%zu is out of range: the %s has %zu", lo, hi, what, count);
    kv_bytes_fail(msg);
}

kv_bytes kv_bytes_slice(const kv_bytes *b, size_t lo, size_t hi) {
    if (lo > hi || hi > b->count)
        kv_slice_range(lo, hi, b->count, "Bytes");
    return kv_bytes_from(b->at + lo, hi - lo);
}

/* room for n bytes and the NUL, doubling from 16 */
void kv_bytes_reserve(kv_bytes *b, size_t n) {
    if (n + 1 <= b->cap)
        return;
    size_t cap = b->cap ? b->cap : 16;
    while (cap < n + 1)
        cap *= 2;
    uint8_t *at = realloc(b->at, cap);
    if (!at)
        kv_bytes_fail("out of memory");
    if (!b->at)
        at[0] = 0;
    b->at = at;
    b->cap = cap;
}

kv_bytes kv_bytes_new(void) { return (kv_bytes){0}; }

kv_bytes kv_bytes_zeros(size_t n) {
    kv_bytes b = {0};
    kv_bytes_reserve(&b, n);
    memset(b.at, 0, n + 1);
    b.count = n;
    return b;
}

kv_bytes kv_bytes_from(const void *p, size_t n) {
    kv_bytes b = {0};
    if (!n)
        return b;
    kv_bytes_reserve(&b, n);
    memcpy(b.at, p, n);
    b.at[n] = 0;
    b.count = n;
    return b;
}

kv_bytes kv_bytes_text(const void *s) { return s ? kv_bytes_from(s, strlen(s)) : (kv_bytes){0}; }

kv_bytes kv_bytes_copy(const kv_bytes *b) { return kv_bytes_from(b->at, b->count); }

kv_bytes kv_bytes_take(kv_bytes *b) {
    kv_bytes v = *b;
    *b = (kv_bytes){0};
    return v;
}

void kv_bytes_free(kv_bytes *b) {
    free(b->at);
    *b = (kv_bytes){0};
}

/* b takes v, an owner; what b held is freed */
void kv_bytes_assign(kv_bytes *b, kv_bytes v) {
    free(b->at);
    *b = v;
}

const uint8_t *kv_bytes_cstr(const kv_bytes *b) { return b->at ? b->at : (const uint8_t *)""; }

uint8_t *kv_bytes_at(const kv_bytes *b, size_t i) {
    if (i >= b->count) {
        char msg[96];
        snprintf(msg, sizeof msg, "index %zu is out of range: the Bytes has %zu", i, b->count);
        kv_bytes_fail(msg);
    }
    return b->at + i;
}

void kv_bytes_append(kv_bytes *b, const void *p, size_t n) {
    if (!n)
        return;
    kv_bytes_reserve(b, b->count + n);
    memmove(b->at + b->count, p, n); /* p may point into b */
    b->count += n;
    b->at[b->count] = 0;
}

void kv_bytes_append_text(kv_bytes *b, const void *s) {
    if (s)
        kv_bytes_append(b, s, strlen(s));
}

void kv_bytes_append_ref(kv_bytes *b, const kv_bytes *v) { kv_bytes_append(b, v->at, v->count); }

/* v, an owner, is appended and freed */
void kv_bytes_append_owned(kv_bytes *b, kv_bytes v) {
    kv_bytes_append(b, v.at, v.count);
    free(v.at);
}

void kv_bytes_push(kv_bytes *b, uint8_t c) { kv_bytes_append(b, &c, 1); }

void kv_bytes_insert(kv_bytes *b, size_t i, const void *p, size_t n) {
    if (i > b->count) {
        char msg[96];
        snprintf(msg, sizeof msg, "insert at %zu is out of range: the Bytes has %zu", i, b->count);
        kv_bytes_fail(msg);
    }
    if (!n)
        return;
    kv_bytes_reserve(b, b->count + n);
    memmove(b->at + i + n, b->at + i, b->count - i + 1);
    memmove(b->at + i, p, n);
    b->count += n;
}

void kv_bytes_insert_text(kv_bytes *b, size_t i, const void *s) {
    if (s)
        kv_bytes_insert(b, i, s, strlen(s));
}

void kv_bytes_insert_ref(kv_bytes *b, size_t i, const kv_bytes *v) { kv_bytes_insert(b, i, v->at, v->count); }

void kv_bytes_insert_owned(kv_bytes *b, size_t i, kv_bytes v) {
    kv_bytes_insert(b, i, v.at, v.count);
    free(v.at);
}

void kv_bytes_insert_byte(kv_bytes *b, size_t i, uint8_t c) { kv_bytes_insert(b, i, &c, 1); }

void kv_bytes_remove(kv_bytes *b, size_t i, size_t n) {
    if (i > b->count || n > b->count - i) {
        char msg[96];
        snprintf(msg, sizeof msg, "remove of %zu at %zu is out of range: the Bytes has %zu", n, i, b->count);
        kv_bytes_fail(msg);
    }
    if (!n)
        return;
    memmove(b->at + i, b->at + i + n, b->count - i - n + 1);
    b->count -= n;
}

void kv_bytes_clear(kv_bytes *b) {
    b->count = 0;
    if (b->at)
        b->at[0] = 0;
}

/* the capacity shrinks to the count, and an empty Bytes frees its heap */
void kv_bytes_compact(kv_bytes *b) {
    if (!b->at)
        return;
    if (!b->count) {
        kv_bytes_free(b);
        return;
    }
    uint8_t *at = realloc(b->at, b->count + 1);
    if (at) {
        b->at = at;
        b->cap = b->count + 1;
    }
}

bool kv_bytes_eq(const kv_bytes *a, const kv_bytes *b) {
    return a->count == b->count && (!a->count || !memcmp(a->at, b->at, a->count));
}

/* print, template and derived text: the bytes as text, NULs included for
   print; a template or a struct's text cuts as a string is cut */
void kv_print_bytes(kv_bytes b) {
    if (b.count)
        fwrite(b.at, 1, b.count, stdout);
}

uint8_t *kv_cstr_bytes(kv_bytes b, uint8_t *buf) {
    size_t n = b.count < KV_CSTR_SCALAR - 4 ? b.count : KV_CSTR_SCALAR - 4;
    memcpy(buf, b.at, n);
    if (n < b.count)
        memcpy(buf + n, "...", 3), n += 3;
    buf[n] = 0;
    return buf;
}

char *kv_template_bytes_owner(char *p, size_t max, kv_bytes b) { return kv_template_bytes(p, max, b.count, b.at ? b.at : (const uint8_t *)""); }

/* a Bytes an expression gave, dropped as a statement */
void kv_bytes_discard(kv_bytes v) { free(v.at); }
