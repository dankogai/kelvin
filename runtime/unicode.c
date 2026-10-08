/* unicode.c - String (#55): a sequence of Unicode codepoints, kept as
   UTF-8 in a Bytes, with its count of codepoints; malformed text is
   refused, by an abort where it is made. */
#include "kelvin_prelude.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void kv_string_fail(const char *what) {
    fflush(stdout);
    fprintf(stderr, "kelvin: %s\n", what);
    abort();
}

/* Is p[0..n) well-formed UTF-8 (no overlong forms, no surrogates, nothing
   past U+10FFFF)? Then *count is its codepoints. */
bool kv_utf8_valid(const uint8_t *p, size_t n, size_t *count) {
    size_t i = 0, c = 0;
    while (i < n) {
        uint8_t b = p[i];
        size_t len;
        uint32_t min, cp;
        if (b < 0x80) { len = 1; min = 0; cp = b; }
        else if ((b & 0xE0) == 0xC0) { len = 2; min = 0x80; cp = b & 0x1F; }
        else if ((b & 0xF0) == 0xE0) { len = 3; min = 0x800; cp = b & 0x0F; }
        else if ((b & 0xF8) == 0xF0) { len = 4; min = 0x10000; cp = b & 0x07; }
        else return false;
        if (i + len > n)
            return false;
        for (size_t k = 1; k < len; k++) {
            if ((p[i + k] & 0xC0) != 0x80)
                return false;
            cp = (cp << 6) | (p[i + k] & 0x3F);
        }
        if (cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF))
            return false;
        i += len;
        c++;
    }
    if (count)
        *count = c;
    return true;
}

/* the codepoint at *p, which is well-formed, and *p moved past it */
uint32_t kv_utf8_next(const uint8_t **p) {
    const uint8_t *s = *p;
    uint32_t cp;
    size_t len;
    if (s[0] < 0x80) { cp = s[0]; len = 1; }
    else if ((s[0] & 0xE0) == 0xC0) { cp = s[0] & 0x1F; len = 2; }
    else if ((s[0] & 0xF0) == 0xE0) { cp = s[0] & 0x0F; len = 3; }
    else { cp = s[0] & 0x07; len = 4; }
    for (size_t k = 1; k < len; k++)
        cp = (cp << 6) | (s[k] & 0x3F);
    *p = s + len;
    return cp;
}

/* the UTF-8 of a codepoint, 1 to 4 bytes; 0 for one that is no codepoint */
static size_t kv_utf8_put(uint32_t cp, uint8_t out[4]) {
    if (cp < 0x80) { out[0] = (uint8_t)cp; return 1; }
    if (cp < 0x800) { out[0] = 0xC0 | (cp >> 6); out[1] = 0x80 | (cp & 0x3F); return 2; }
    if (cp >= 0xD800 && cp <= 0xDFFF)
        return 0;
    if (cp < 0x10000) { out[0] = 0xE0 | (cp >> 12); out[1] = 0x80 | ((cp >> 6) & 0x3F); out[2] = 0x80 | (cp & 0x3F); return 3; }
    if (cp > 0x10FFFF)
        return 0;
    out[0] = 0xF0 | (cp >> 18); out[1] = 0x80 | ((cp >> 12) & 0x3F); out[2] = 0x80 | ((cp >> 6) & 0x3F); out[3] = 0x80 | (cp & 0x3F);
    return 4;
}

static void kv_string_check(const void *p, size_t n, size_t *count) {
    if (!kv_utf8_valid(p, n, count))
        kv_string_fail("malformed UTF-8: a String holds well-formed text only");
}

kv_string kv_string_new(void) { return (kv_string){0}; }

kv_string kv_string_text(const void *s) {
    kv_string r = {0};
    if (!s)
        return r;
    size_t n = strlen(s);
    kv_string_check(s, n, &r.count);
    r.b = kv_bytes_from(s, n);
    return r;
}

kv_string kv_string_from_bytes(const kv_bytes *b) {
    kv_string r = {0};
    kv_string_check(b->at ? b->at : (const uint8_t *)"", b->count, &r.count);
    r.b = kv_bytes_copy(b);
    return r;
}

kv_string kv_string_copy(const kv_string *s) { return (kv_string){kv_bytes_copy(&s->b), s->count}; }

kv_string kv_string_take(kv_string *s) {
    kv_string v = *s;
    *s = (kv_string){0};
    return v;
}

void kv_string_free(kv_string *s) {
    kv_bytes_free(&s->b);
    s->count = 0;
}

void kv_string_assign(kv_string *s, kv_string v) {
    kv_bytes_free(&s->b);
    *s = v;
}

void kv_string_discard(kv_string v) { kv_bytes_free(&v.b); }

void kv_string_append_text(kv_string *s, const void *t) {
    if (!t)
        return;
    size_t n = strlen(t), c;
    kv_string_check(t, n, &c);
    kv_bytes_append(&s->b, t, n);
    s->count += c;
}

void kv_string_append_ref(kv_string *s, const kv_string *t) {
    kv_bytes_append(&s->b, t->b.at, t->b.count);
    s->count += t->count;
}

void kv_string_append_owned(kv_string *s, kv_string t) {
    kv_string_append_ref(s, &t);
    kv_bytes_free(&t.b);
}

void kv_string_append_cp(kv_string *s, uint32_t cp) {
    uint8_t out[4];
    size_t n = kv_utf8_put(cp, out);
    if (!n)
        kv_string_fail("not a codepoint: a String holds U+0000 to U+10FFFF, no surrogates");
    kv_bytes_append(&s->b, out, n);
    s->count++;
}

void kv_string_clear(kv_string *s) {
    kv_bytes_clear(&s->b);
    s->count = 0;
}

void kv_string_reserve(kv_string *s, size_t n) { kv_bytes_reserve(&s->b, n); }
void kv_string_compact(kv_string *s) { kv_bytes_compact(&s->b); }

bool kv_string_eq(const kv_string *a, const kv_string *b) { return kv_bytes_eq(&a->b, &b->b); }

bool kv_bytes_is_utf8(const kv_bytes *b) { return kv_utf8_valid(b->at ? b->at : (const uint8_t *)"", b->count, NULL); }

void kv_print_string(kv_string s) { kv_print_bytes(s.b); }
uint8_t *kv_cstr_string(kv_string s, uint8_t *buf) { return kv_cstr_bytes(s.b, buf); }
char *kv_template_string(char *p, size_t max, kv_string s) { return kv_template_bytes_owner(p, max, s.b); }
