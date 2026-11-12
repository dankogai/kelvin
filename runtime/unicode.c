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
    kv_exit_failure();
}

/* Where p[0..n) stops being well-formed UTF-8 (an overlong form, a
   surrogate, past U+10FFFF), the offset of the codepoint that is not; n if
   it never does, and then *count is its codepoints (#405). */
size_t kv_utf8_scan(const uint8_t *p, size_t n, size_t *count) {
    size_t i = 0, c = 0;
    while (i < n) {
        uint8_t b = p[i];
        size_t len;
        uint32_t min, cp;
        if (b < 0x80) { len = 1; min = 0; cp = b; }
        else if ((b & 0xE0) == 0xC0) { len = 2; min = 0x80; cp = b & 0x1F; }
        else if ((b & 0xF0) == 0xE0) { len = 3; min = 0x800; cp = b & 0x0F; }
        else if ((b & 0xF8) == 0xF0) { len = 4; min = 0x10000; cp = b & 0x07; }
        else return i;
        if (i + len > n)
            return i;
        for (size_t k = 1; k < len; k++) {
            if ((p[i + k] & 0xC0) != 0x80)
                return i;
            cp = (cp << 6) | (p[i + k] & 0x3F);
        }
        if (cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF))
            return i;
        i += len;
        c++;
    }
    if (count)
        *count = c;
    return n;
}

/* Is p[0..n) well-formed UTF-8? Then *count is its codepoints. */
bool kv_utf8_valid(const uint8_t *p, size_t n, size_t *count) { return kv_utf8_scan(p, n, count) == n; }

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

/* b.string() (#405): a String of the bytes in *out, and -1; or, of bytes
   that are not UTF-8, the offset of the first that is not, *out left empty */
int64_t kv_string_try_bytes(const kv_bytes *b, kv_string *out) {
    size_t count = 0, at = kv_utf8_scan(b->at ? b->at : (const uint8_t *)"", b->count, &count);
    if (at != b->count)
        return (int64_t)at;
    *out = (kv_string){kv_bytes_copy(b), count};
    return -1;
}

kv_string kv_string_copy(const kv_string *s) { return (kv_string){kv_bytes_copy(&s->b), s->count}; }

/* ---------- graphemes (#522): a String's elements ---------- */

/* a String of the n bytes at p, well-formed UTF-8 already, its codepoints
   counted */
kv_string kv_string_span(const uint8_t *p, size_t n) {
    if (!n)
        return (kv_string){0};
    size_t count = 0;
    for (size_t i = 0; i < n; i++)
        count += (p[i] & 0xC0) != 0x80;
    return (kv_string){kv_bytes_from(p, n), count};
}

/* the graphemes of s, what a reader sees as characters (UAX #29); of
   ASCII alone each byte but the LF of a CR LF */
size_t kv_string_graphemes(const kv_string *s) {
    const uint8_t *p = s->b.at;
    size_t n = s->b.count, k = 0;
    if (s->count == n) {
        for (size_t i = 0; i < n; i++)
            k += !(p[i] == '\n' && i > 0 && p[i - 1] == '\r');
        return k;
    }
    while (n) {
        size_t g = kv_ucd_grapheme_len(p, n);
        p += g;
        n -= g;
        k++;
    }
    return k;
}

/* the byte offset of grapheme i of s, the bytes' count at the end;
   SIZE_MAX past it */
static size_t grapheme_byte(const kv_string *s, size_t i) {
    const uint8_t *p = s->b.at;
    size_t n = s->b.count, at = 0;
    for (size_t k = 0; k < i; k++) {
        if (at >= n)
            return SIZE_MAX;
        at += kv_ucd_grapheme_len(p + at, n - at);
    }
    return at;
}

/* the graphemes lo..<hi (#68, #522), a new String */
kv_string kv_string_slice(const kv_string *s, size_t lo, size_t hi) {
    size_t from = lo <= hi ? grapheme_byte(s, lo) : SIZE_MAX;
    size_t to = from != SIZE_MAX ? grapheme_byte(s, hi) : SIZE_MAX;
    if (lo > hi || to == SIZE_MAX) {
        char msg[128];
        snprintf(msg, sizeof msg, "range %zu..<%zu is out of range: the String has %zu graphemes", lo, hi,
                 kv_string_graphemes(s));
        kv_array_fail(msg);
    }
    return kv_string_span(s->b.at + from, to - from);
}

/* s[i] (#522): grapheme i, a new String; past the end ends the program */
kv_string kv_string_grapheme(const kv_string *s, int64_t i) {
    size_t from = i < 0 ? SIZE_MAX : grapheme_byte(s, (size_t)i);
    if (from == SIZE_MAX || from >= s->b.count) {
        char msg[128];
        snprintf(msg, sizeof msg, "index %lld is out of range: the String has %zu graphemes", (long long)i,
                 kv_string_graphemes(s));
        kv_array_fail(msg);
    }
    return kv_string_span(s->b.at + from, kv_ucd_grapheme_len(s->b.at + from, s->b.count - from));
}

/* s.prefix(n) (#372, #522): the first n graphemes, all where there are
   fewer, none of n 0 or less */
kv_string kv_string_prefix(const kv_string *s, int64_t n) {
    const uint8_t *p = s->b.at;
    size_t len = s->b.count, at = 0;
    for (int64_t k = 0; k < n && at < len; k++)
        at += kv_ucd_grapheme_len(p + at, len - at);
    return kv_string_span(p, at);
}

/* the index of the grapheme of s that holds byte b, the graphemes' count
   at the end: a byte offset as a grapheme index, rounded down */
size_t kv_string_grapheme_floor(const kv_string *s, size_t b) {
    const uint8_t *p = s->b.at;
    size_t n = s->b.count, at = 0, k = 0;
    while (at < n) {
        size_t g = kv_ucd_grapheme_len(p + at, n - at);
        if (at + g > b)
            return k;
        at += g;
        k++;
    }
    return k;
}

/* the graphemes of s that begin before byte b: a byte offset as a
   grapheme index, rounded up */
size_t kv_string_grapheme_ceil(const kv_string *s, size_t b) {
    const uint8_t *p = s->b.at;
    size_t n = s->b.count, at = 0, k = 0;
    while (at < n && at < b) {
        at += kv_ucd_grapheme_len(p + at, n - at);
        k++;
    }
    return k;
}

/* the byte offset of grapheme i of s, the bytes' count past the end, 0
   before the start */
size_t kv_string_grapheme_byte(const kv_string *s, int64_t i) {
    if (i <= 0)
        return 0;
    size_t at = grapheme_byte(s, (size_t)i);
    return at == SIZE_MAX ? s->b.count : at;
}

/* s == 'x' (#522): whether s is the one codepoint */
bool kv_string_eq_cp(const kv_string *s, uint32_t cp) {
    const uint8_t *p = s->b.at;
    return s->count == 1 && kv_utf8_next(&p) == cp;
}

/* the byte offset of codepoint i of s, the bytes' count past the end */
size_t kv_string_codepoint_byte(const kv_string *s, size_t i) {
    const uint8_t *p = s->b.at;
    size_t n = s->b.count, at = 0;
    for (size_t k = 0; k < i && at < n; k++) {
        at++;
        while (at < n && (p[at] & 0xC0) == 0x80)
            at++;
    }
    return at;
}

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
void kv_fprint_string(void *fp, kv_string s) { kv_fprint_bytes(fp, s.b); }
uint8_t *kv_cstr_string(kv_string s, uint8_t *buf) { return kv_cstr_bytes(s.b, buf); }
char *kv_template_string(char *p, size_t max, kv_string s) { return kv_template_bytes_owner(p, max, s.b); }

int kv_string_cmp(const kv_string *a, const kv_string *b) { return kv_bytes_cmp(&a->b, &b->b); } /* (#185) */
