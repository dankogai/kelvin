/* bits.c - Bits (#387, #455): bits in u64s on the heap, place 0 the
   lowest bit of the first, an owner as a Bytes is. count is in bits, cap
   in u64s; the bits past count in the last u64 are always 0, so == and
   the text read the u64s as they are. An empty Bits has at == NULL and
   nothing to free. A place past count, and text that is no 0b..., end
   the program. Its text is Bits("0b..."), each bit a digit, the highest
   place first, which pastes back; an empty one Bits() */
#include "kelvin_prelude.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static size_t words(size_t bits) { return (bits + 63) / 64; }

static void bits_fail(const char *what) {
    fflush(stdout);
    fprintf(stderr, "kelvin: %s\n", what);
    kv_exit_failure();
}

/* room for n u64s, doubling from 1 */
static void room(kv_bits *b, size_t n) {
    if (n <= b->cap)
        return;
    size_t cap = b->cap ? b->cap : 1;
    while (cap < n)
        cap *= 2;
    uint64_t *at = realloc(b->at, cap * sizeof *at);
    if (!at)
        bits_fail("out of memory");
    memset(at + b->cap, 0, (cap - b->cap) * sizeof *at);
    b->at = at;
    b->cap = cap;
}

kv_bits kv_bits_new(void) { return (kv_bits){0}; }

kv_bits kv_bits_copy(const kv_bits *b) {
    kv_bits c = {0};
    room(&c, words(b->count));
    if (b->count)
        memcpy(c.at, b->at, words(b->count) * sizeof *c.at);
    c.count = b->count;
    return c;
}

kv_bits kv_bits_take(kv_bits *b) {
    kv_bits v = *b;
    *b = (kv_bits){0};
    return v;
}

void kv_bits_free(kv_bits *b) {
    free(b->at);
    *b = (kv_bits){0};
}

void kv_bits_assign(kv_bits *b, kv_bits v) {
    free(b->at);
    *b = v;
}

void kv_bits_discard(kv_bits v) { free(v.at); }

/* .capacity(n) (#455): room for n bits, a multiple of 64; it never
   shrinks */
void kv_bits_reserve(kv_bits *b, int64_t n) {
    if (n < 0)
        bits_fail("a Bits's capacity is 0 or more bits, and this is less");
    size_t w = words((size_t)n);
    if (w <= b->cap)
        return;
    uint64_t *at = realloc(b->at, w * sizeof *at);
    if (!at)
        bits_fail("out of memory");
    memset(at + b->cap, 0, (w - b->cap) * sizeof *at);
    b->at = at;
    b->cap = w;
}

void kv_bits_push(kv_bits *b, bool v) {
    room(b, words(b->count + 1));
    if (v)
        b->at[b->count / 64] |= (uint64_t)1 << (b->count % 64);
    b->count++;
}

/* an integer's w bits, its lowest first (#455) */
void kv_bits_push_int(kv_bits *b, unsigned __int128 v, unsigned w) {
    room(b, words(b->count + w));
    for (unsigned i = 0; i < w; i++)
        kv_bits_push(b, (bool)(v >> i & 1));
}

/* a [bool]'s n bools, its first at the lowest place (#455) */
void kv_bits_push_bools(kv_bits *b, const bool *p, size_t n) {
    room(b, words(b->count + n));
    for (size_t i = 0; i < n; i++)
        kv_bits_push(b, p[i]);
}

/* "0b101": its n bytes, 0b and binary digits, the last at the lowest
   place, as a binary literal is (#455) */
void kv_bits_push_text(kv_bits *b, const void *s, size_t n) {
    const uint8_t *t = s;
    if (n < 2 || t[0] != '0' || t[1] != 'b')
        bits_fail("a Bits's text is 0b and binary digits, as \"0b101\", and this is not");
    for (size_t i = n; i > 2; i--) {
        if (t[i - 1] != '0' && t[i - 1] != '1')
            bits_fail("a Bits's text is 0b and binary digits, as \"0b101\", and this is not");
        kv_bits_push(b, t[i - 1] == '1');
    }
}

void kv_bits_push_cstr(kv_bits *b, const void *s) { kv_bits_push_text(b, s, s ? strlen(s) : 0); }

/* a place 0 to count - 1, else the program ends */
static size_t place(const kv_bits *b, int64_t n) {
    if (n < 0 || (uint64_t)n >= b->count) {
        char msg[128];
        snprintf(msg, sizeof msg, "place %lld is out of range: the Bits has %zu bits", (long long)n, b->count);
        bits_fail(msg);
    }
    return (size_t)n;
}

bool kv_bits_at(const kv_bits *b, int64_t n) {
    size_t i = place(b, n);
    return b->at[i / 64] >> (i % 64) & 1;
}

void kv_bits_put(kv_bits *b, int64_t n, bool v) {
    size_t i = place(b, n);
    uint64_t m = (uint64_t)1 << (i % 64);
    b->at[i / 64] = v ? b->at[i / 64] | m : b->at[i / 64] & ~m;
}

void kv_bits_or(kv_bits *b, int64_t n, bool v) {
    if (v)
        kv_bits_put(b, n, true);
    else
        place(b, n);
}

void kv_bits_and(kv_bits *b, int64_t n, bool v) {
    if (!v)
        kv_bits_put(b, n, false);
    else
        place(b, n);
}

void kv_bits_xor(kv_bits *b, int64_t n, bool v) {
    size_t i = place(b, n);
    if (v)
        b->at[i / 64] ^= (uint64_t)1 << (i % 64);
}

void kv_bits_flip(kv_bits *b, int64_t n) { kv_bits_xor(b, n, true); }

/* a | b, a & b, a ~ b (op '|', '&', '^'), into a (#455): of the longer
   count, the shorter's missing bits false */
void kv_bits_with(kv_bits *a, const kv_bits *b, char op) {
    size_t n = a->count > b->count ? a->count : b->count, wb = words(b->count);
    room(a, words(n));
    for (size_t i = 0; i < words(n); i++) {
        uint64_t y = i < wb ? b->at[i] : 0;
        a->at[i] = op == '|' ? a->at[i] | y : op == '&' ? a->at[i] & y : a->at[i] ^ y;
    }
    a->count = n;
}

kv_bits kv_bits_op(const kv_bits *a, const kv_bits *b, char op) {
    kv_bits r = kv_bits_copy(a);
    kv_bits_with(&r, b, op);
    return r;
}

/* the bits past count in the last u64 cleared, as each Bits keeps them */
static void trim(kv_bits *b) {
    if (b->count % 64)
        b->at[b->count / 64] &= ((uint64_t)1 << (b->count % 64)) - 1;
    for (size_t i = words(b->count); i < b->cap; i++)
        b->at[i] = 0;
}

kv_bits kv_bits_not(const kv_bits *a) {
    kv_bits r = kv_bits_copy(a);
    for (size_t i = 0; i < words(r.count); i++)
        r.at[i] = ~r.at[i];
    trim(&r);
    return r;
}

static uint64_t shift_of(int64_t n) {
    if (n < 0)
        bits_fail("a Bits shifts by 0 or more places, and this is less");
    return (uint64_t)n;
}

/* bv <<= n (#455): n false bits at place 0, the count n more */
void kv_bits_shl_assign(kv_bits *b, int64_t n) {
    uint64_t s = shift_of(n);
    if (!s || !b->count)
        return;
    size_t old = words(b->count), count = b->count + (size_t)s, ws = (size_t)(s / 64), bs = (size_t)(s % 64);
    room(b, words(count));
    for (size_t i = words(count); i-- > 0;) {
        uint64_t lo = i >= ws && i - ws < old ? b->at[i - ws] : 0;
        uint64_t below = bs && i >= ws + 1 && i - ws - 1 < old ? b->at[i - ws - 1] >> (64 - bs) : 0;
        b->at[i] = (bs ? lo << bs : lo) | below;
    }
    b->count = count;
    trim(b);
}

/* bv >>= n (#455): the n lowest bits gone, the count n fewer, or none */
void kv_bits_shr_assign(kv_bits *b, int64_t n) {
    uint64_t s = shift_of(n);
    if (!s)
        return;
    if (s >= b->count) {
        for (size_t i = 0; i < b->cap; i++)
            b->at[i] = 0;
        b->count = 0;
        return;
    }
    size_t old = words(b->count), count = b->count - (size_t)s, ws = (size_t)(s / 64), bs = (size_t)(s % 64);
    for (size_t i = 0; i < words(count); i++) {
        uint64_t lo = i + ws < old ? b->at[i + ws] : 0;
        uint64_t above = bs && i + ws + 1 < old ? b->at[i + ws + 1] << (64 - bs) : 0;
        b->at[i] = (bs ? lo >> bs : lo) | above;
    }
    b->count = count;
    trim(b);
}

kv_bits kv_bits_shl(const kv_bits *b, int64_t n) {
    kv_bits r = kv_bits_copy(b);
    kv_bits_shl_assign(&r, n);
    return r;
}

kv_bits kv_bits_shr(const kv_bits *b, int64_t n) {
    kv_bits r = kv_bits_copy(b);
    kv_bits_shr_assign(&r, n);
    return r;
}

bool kv_bits_eq(const kv_bits *a, const kv_bits *b) {
    return a->count == b->count && (!a->count || !memcmp(a->at, b->at, words(a->count) * sizeof *a->at));
}

/* .bin's text of u64 i (#455): 0b and its bits, the highest first, 64
   but in the last, which has the rest */
kv_string kv_bits_word_bin(const kv_bits *b, size_t i) {
    size_t n = i + 1 < words(b->count) || !(b->count % 64) ? 64 : b->count % 64;
    uint8_t text[67] = "0b";
    for (size_t k = 0; k < n; k++)
        text[2 + k] = (uint8_t)('0' + (b->at[i] >> (n - 1 - k) & 1));
    text[2 + n] = 0;
    return kv_string_lit(text, 2 + n);
}

/* the text, cut at max bytes as a string's is: Bits("0b...") */
static size_t text_of(const kv_bits *b, uint8_t *out, size_t max) {
    size_t n = 0;
    const char *head = b->count ? "Bits(\"0b" : "Bits()";
    for (const char *h = head; *h && n < max; h++)
        out[n++] = (uint8_t)*h;
    if (!b->count)
        return n;
    for (size_t k = b->count; k-- > 0 && n < max;)
        out[n++] = (uint8_t)('0' + (b->at[k / 64] >> (k % 64) & 1));
    for (const char *t = "\")"; *t && n < max; t++)
        out[n++] = (uint8_t)*t;
    return n;
}

static size_t text_size(const kv_bits *b) { return b->count ? 10 + b->count : 6; }

/* .cstr (#455): in the block's buffer of KV_CSTR_SCALAR bytes, a longer
   text cut and ending in "...", as a string's in a struct's text is */
uint8_t *kv_cstr_bits(kv_bits b, uint8_t *buf) {
    size_t n = text_of(&b, buf, KV_CSTR_SCALAR - 1);
    if (text_size(&b) > KV_CSTR_SCALAR - 1)
        memcpy(buf + KV_CSTR_SCALAR - 4, "...", 3);
    buf[n] = 0;
    return buf;
}

void kv_fprint_bits(void *fp, kv_bits b) {
    uint8_t *out = malloc(text_size(&b) + 1);
    if (!out)
        bits_fail("out of memory");
    size_t n = text_of(&b, out, text_size(&b));
    fwrite(out, 1, n, (FILE *)fp);
    free(out);
}

void kv_print_bits(kv_bits b) { kv_fprint_bits(stdout, b); }

char *kv_template_bits(char *p, size_t max, kv_bits b) {
    uint8_t *out = malloc(text_size(&b) + 1);
    if (!out)
        bits_fail("out of memory");
    size_t n = text_of(&b, out, text_size(&b));
    p = kv_template_bytes(p, max, n, out);
    free(out);
    return p;
}
