/* kelvin_prelude.h - the Kelvin prelude, available to every Kelvin program

   kelvinc includes this header in the C it generates and links
   libkelvin. It declares no libc functions, so it never conflicts with
   prototypes a Kelvin program writes by hand.

     print(v, ...)    prints each value according to its type
     println(v, ...)  the same, followed by a newline; println() prints
                      just a newline
     v.cstr           the text of a value, as cstr (u8^) on the stack
     v.dec, v.hex     the text of a number (and v.oct, v.bin for integers)

   print: integers print in decimal (including 128-bit ones), floats in
   the shortest form that reads back to the same value, bool as
   true/false, byte pointers (u8^, string literals) as strings and other
   pointers as addresses. Up to 16 values per call. As in Swift, a float
   is plain decimal from 0.0001 up to 2 to the power of its type's
   mantissa bits (2^53 for double, 2^24 for float, LDBL_MANT_DIG bits for
   long double) and has an exponent otherwise (10.0, 1e+16, 1e-05),
   always with '.', whatever the C locale's decimal point. */
#ifndef KELVIN_PRELUDE_H
#define KELVIN_PRELUDE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* ---------- x.cstr (#22) ---------- */

/* The text of a value, written into `buf` (a buffer on the caller's
   stack that kelvinc declares at the top of the enclosing block) and
   returned as u8^. Numbers are plain decimal ("42", "-7"), floats are
   lossless (%.9g for f32, %.17g for f64) and a NaN is "nan", bool is
   true/false, other pointers are addresses ("0x1f2e"), complex numbers
   are re+imi. A string (u8^) is its own text: s.cstr is s itself, and
   stays const if s is.
   A Kelvin struct's text, {x: 3, y: 4}, is written by a function kelvinc
   derives for it. A buffer for one value holds KV_CSTR_SCALAR bytes. */
#define KV_CSTR_SCALAR 64
#include <stdlib.h> /* realloc and free, for Array<T>'s functions (#57) */
#include <string.h>

/* ---------- Bytes (#54): an owner, a growable array of u8 ---------- */

/* at[count] is a NUL that count does not count, so cstr borrows it; an
   empty Bytes has at == NULL. A variable owns one and its block frees it
   (cleanup); it moves by return and by passing, and copies by copy(). */
typedef struct kv_bytes { uint8_t *at; size_t count, cap; } kv_bytes;
kv_bytes kv_bytes_new(void);
kv_bytes kv_bytes_zeros(size_t n);
kv_bytes kv_bytes_from(const void *p, size_t n);
kv_bytes kv_bytes_text(const void *s);
kv_bytes kv_bytes_copy(const kv_bytes *b);
kv_bytes kv_bytes_take(kv_bytes *b);
void kv_bytes_free(kv_bytes *b);
void kv_bytes_assign(kv_bytes *b, kv_bytes v);
void kv_bytes_discard(kv_bytes v);
const uint8_t *kv_bytes_cstr(const kv_bytes *b);
uint8_t *kv_bytes_at(const kv_bytes *b, size_t i);
void kv_bytes_reserve(kv_bytes *b, size_t n);
void kv_bytes_append(kv_bytes *b, const void *p, size_t n);
void kv_bytes_append_text(kv_bytes *b, const void *s);
void kv_bytes_append_ref(kv_bytes *b, const kv_bytes *v);
void kv_bytes_append_owned(kv_bytes *b, kv_bytes v);
void kv_bytes_push(kv_bytes *b, uint8_t c);
void kv_bytes_insert(kv_bytes *b, size_t i, const void *p, size_t n);
void kv_bytes_insert_text(kv_bytes *b, size_t i, const void *s);
void kv_bytes_insert_ref(kv_bytes *b, size_t i, const kv_bytes *v);
void kv_bytes_insert_owned(kv_bytes *b, size_t i, kv_bytes v);
void kv_bytes_insert_byte(kv_bytes *b, size_t i, uint8_t c);
void kv_bytes_remove(kv_bytes *b, size_t i, size_t n);
void kv_bytes_clear(kv_bytes *b);
void kv_bytes_compact(kv_bytes *b);
bool kv_bytes_eq(const kv_bytes *a, const kv_bytes *b);
void kv_print_bytes(kv_bytes b);
uint8_t *kv_cstr_bytes(kv_bytes b, uint8_t *buf);
char *kv_template_bytes_owner(char *p, size_t max, kv_bytes b);
/* ---------- String (#55): codepoints, as UTF-8 in a Bytes ---------- */

/* b holds well-formed UTF-8, and count its codepoints; malformed text
   aborts where a String is made or appended */
typedef struct kv_string { kv_bytes b; size_t count; } kv_string;
bool kv_utf8_valid(const uint8_t *p, size_t n, size_t *count);
uint32_t kv_utf8_next(const uint8_t **p);
kv_string kv_string_new(void);
kv_string kv_string_text(const void *s);
kv_string kv_string_from_bytes(const kv_bytes *b);
kv_string kv_string_copy(const kv_string *s);
kv_string kv_string_take(kv_string *s);
void kv_string_free(kv_string *s);
void kv_string_assign(kv_string *s, kv_string v);
void kv_string_discard(kv_string v);
void kv_string_append_text(kv_string *s, const void *t);
void kv_string_append_ref(kv_string *s, const kv_string *t);
void kv_string_append_owned(kv_string *s, kv_string t);
void kv_string_append_cp(kv_string *s, uint32_t cp);
void kv_string_clear(kv_string *s);
void kv_string_reserve(kv_string *s, size_t n);
void kv_string_compact(kv_string *s);
bool kv_string_eq(const kv_string *a, const kv_string *b);
kv_string kv_string_slice(const kv_string *s, size_t lo, size_t hi); /* codepoints lo..<hi (#68) */
bool kv_bytes_is_utf8(const kv_bytes *b);
void kv_print_string(kv_string s);
uint8_t *kv_cstr_string(kv_string s, uint8_t *buf);
char *kv_template_string(char *p, size_t max, kv_string s);
/* uchr (#56): a codepoint on the stack, shown as its UTF-8 */
typedef struct kv_uchr { uint32_t cp; } kv_uchr;
kv_uchr kv_uchr_of(uint64_t n);
kv_uchr kv_uchr_first(const void *text);
uint8_t *kv_cstr_uchr(kv_uchr c, uint8_t *buf);
void kv_print_uchr(kv_uchr c);
char *kv_template_uchr(char *p, size_t max, kv_uchr c);
void kv_string_append_uchr(kv_string *s, kv_uchr c);
/* uchr(x): of a number, U+FFFD where it is no codepoint; of text, its first codepoint */
#define KV_UCHR_OF(x) _Generic((x), \
    char: kv_uchr_of, signed char: kv_uchr_of, short: kv_uchr_of, int: kv_uchr_of, \
    long: kv_uchr_of, long long: kv_uchr_of, \
    unsigned char: kv_uchr_of, unsigned short: kv_uchr_of, unsigned: kv_uchr_of, \
    unsigned long: kv_uchr_of, unsigned long long: kv_uchr_of, \
    kv_uchr: kv_uchr_same, \
    default: kv_uchr_first)(x)
static inline kv_uchr kv_uchr_same(kv_uchr c) { return c; }

/* String(x): text, validated, or a copy of a Bytes borrow, validated */
#define KV_STRING_OF(x) _Generic((x), \
    kv_bytes *: kv_string_from_bytes, const kv_bytes *: kv_string_from_bytes, \
    default: kv_string_text)(x)
/* s.append(x): a codepoint, text, a String borrow, or a String an expression gives, which is freed */
#define KV_STRING_APPEND(s, x) _Generic((x), \
    char: kv_string_append_cp, signed char: kv_string_append_cp, short: kv_string_append_cp, int: kv_string_append_cp, \
    long: kv_string_append_cp, long long: kv_string_append_cp, \
    unsigned char: kv_string_append_cp, unsigned short: kv_string_append_cp, unsigned: kv_string_append_cp, \
    unsigned long: kv_string_append_cp, unsigned long long: kv_string_append_cp, \
    kv_string: kv_string_append_owned, kv_string *: kv_string_append_ref, const kv_string *: kv_string_append_ref, \
    kv_uchr: kv_string_append_uchr, \
    default: kv_string_append_text)((s), (x))

/* ---------- Array<T> (#57): a growable array of T, an owner ---------- */

/* KV_ARRAY(T, A, FREE, COPY) declares A, the Array of T, and its
   functions, once per element type in a program's C: at[0..count) are
   the elements, cap the room; FREE(p) frees an element that owns and
   COPY(p) copies one (nothing, and *p, for a plain T). The rules are
   Bytes's: a variable owns it, moves by return and passing, copies by
   copy(), and its block frees it, elements included. */
void kv_array_fail(const char *what);
void kv_array_range(size_t i, size_t count);
/* a slice (#68): lo..<hi within count, else the program ends */
void kv_slice_range(size_t lo, size_t hi, size_t count, const char *what);
kv_bytes kv_bytes_slice(const kv_bytes *b, size_t lo, size_t hi);
/* an enum with values (#61): reading a case that is not current */
void kv_case_fail(const char *type, const char *want, const char *have);
/* Dictionary<K, V> (#65): hashes, a text key against a stored String,
   and a missing key, which ends the program */
size_t kv_hash_int(uint64_t x);
size_t kv_hash_text(const void *s);
bool kv_string_eq_text(const kv_string *s, const void *t);
void kv_dict_missing_int(long long k);
void kv_dict_missing_text(const void *k);
#define KV_HASH_INT(k) kv_hash_int((uint64_t)(k))
#define KV_EQ_INT(kp, k) (*(kp) == (k))
#define KV_STORE_INT(k) (k)
#define KV_MISSING_INT(k) kv_dict_missing_int((long long)(k))
#define KV_LK_INT(kp) (*(kp))
#define KV_LK_TEXT(kp) kv_bytes_cstr(&(kp)->b)
#define KV_HASH_TEXT(k) kv_hash_text(k)
#define KV_EQ_TEXT(kp, k) kv_string_eq_text((kp), (k))
#define KV_STORE_TEXT(k) kv_string_text(k)
#define KV_MISSING_TEXT(k) kv_dict_missing_text(k)

/* Set<T> (#71): a hash set on the heap, as a Dictionary with no values;
   LKOF gives the key given back from the key kept, for the set algebra */
#define KV_SET_TYPE(S) \
    typedef struct S##_entry S##_entry; \
    typedef struct S { S##_entry *at; size_t count, len, cap; uint32_t *head; size_t hcap; } S;
#define KV_SET(K, LK, S, HASH, EQ, STORE, LKOF, KFREE, KCOPY) \
    KV_SET_TYPE(S) KV_SET_FUNCS(K, LK, S, HASH, EQ, STORE, LKOF, KFREE, KCOPY)
#define KV_SET_FUNCS(K, LK, S, HASH, EQ, STORE, LKOF, KFREE, KCOPY) \
    struct S##_entry { K key; size_t hash; uint32_t next; bool live; }; \
    __attribute__((unused)) static inline void S##_free(S *s) { \
        for (size_t i = 0; i < s->len; i++) if (s->at[i].live) KFREE(&s->at[i].key); \
        free(s->at); free(s->head); *s = (S){0}; } \
    __attribute__((unused)) static inline S S##_take(S *s) { S v = *s; *s = (S){0}; return v; } \
    __attribute__((unused)) static inline void S##_assign(S *s, S v) { S##_free(s); *s = v; } \
    __attribute__((unused)) static inline void S##_discard(S v) { S##_free(&v); } \
    __attribute__((unused)) static inline S##_entry *S##_lookup(const S *s, LK k, size_t h) { \
        if (!s->hcap) return NULL; \
        for (uint32_t i = s->head[h & (s->hcap - 1)]; i; i = s->at[i - 1].next) \
            if (s->at[i - 1].hash == h && EQ(&s->at[i - 1].key, k)) return &s->at[i - 1]; \
        return NULL; } \
    __attribute__((unused)) static inline void S##_link(S *s, size_t i) { \
        size_t b = s->at[i].hash & (s->hcap - 1); s->at[i].next = s->head[b]; s->head[b] = (uint32_t)(i + 1); } \
    __attribute__((unused)) static inline void S##_rehash(S *s, size_t cap) { \
        S##_entry *at = malloc(cap * sizeof *at); \
        uint32_t *head = malloc(cap * 2 * sizeof *head); \
        if (!at || !head) kv_array_fail("out of memory"); \
        memset(head, 0, cap * 2 * sizeof *head); \
        size_t n = 0; \
        for (size_t i = 0; i < s->len; i++) if (s->at[i].live) at[n++] = s->at[i]; \
        free(s->at); free(s->head); \
        s->at = at; s->len = n; s->cap = cap; s->head = head; s->hcap = cap * 2; \
        for (size_t i = 0; i < n; i++) S##_link(s, i); } \
    __attribute__((unused)) static inline void S##_reserve(S *s, size_t n) { \
        if (n <= s->cap) return; \
        size_t cap = s->cap ? s->cap : 16; \
        while (cap < n) cap *= 2; \
        S##_rehash(s, cap); } \
    __attribute__((unused)) static inline bool S##_has(const S *s, LK k) { return S##_lookup(s, k, HASH(k)) != NULL; } \
    __attribute__((unused)) static inline bool S##_insert(S *s, LK k) { \
        size_t h = HASH(k); \
        if (S##_lookup(s, k, h)) return false; \
        if (s->len == s->cap) S##_rehash(s, !s->cap ? 16 : s->count + 1 > s->cap / 2 ? s->cap * 2 : s->cap); \
        S##_entry *e = &s->at[s->len++]; \
        e->key = STORE(k); e->hash = h; e->live = true; \
        S##_link(s, (size_t)(e - s->at)); s->count++; return true; } \
    __attribute__((unused)) static inline bool S##_remove(S *s, LK k) { \
        if (!s->hcap) return false; \
        size_t h = HASH(k); \
        for (uint32_t *p = &s->head[h & (s->hcap - 1)]; *p; p = &s->at[*p - 1].next) { \
            S##_entry *e = &s->at[*p - 1]; \
            if (e->hash == h && EQ(&e->key, k)) { *p = e->next; KFREE(&e->key); e->live = false; s->count--; return true; } } \
        return false; } \
    __attribute__((unused)) static inline void S##_clear(S *s) { \
        for (size_t i = 0; i < s->len; i++) if (s->at[i].live) KFREE(&s->at[i].key); \
        s->len = 0; s->count = 0; \
        if (s->head) memset(s->head, 0, s->hcap * sizeof *s->head); } \
    __attribute__((unused)) static inline S S##_copy(const S *s) { \
        S v = {0}; S##_reserve(&v, s->count); \
        for (size_t i = 0; i < s->len; i++) if (s->at[i].live) { \
            S##_entry *e = &v.at[v.len++]; \
            e->key = KCOPY(&s->at[i].key); e->hash = s->at[i].hash; e->live = true; \
            S##_link(&v, (size_t)(e - v.at)); v.count++; } \
        return v; } \
    __attribute__((unused)) static inline void S##_insert_all(S *s, const S *t) { \
        for (size_t i = 0; i < t->len; i++) if (t->at[i].live) S##_insert(s, LKOF(&t->at[i].key)); } \
    __attribute__((unused)) static inline S S##_union(const S *a, const S *b) { S v = S##_copy(a); S##_insert_all(&v, b); return v; } \
    __attribute__((unused)) static inline S S##_intersection(const S *a, const S *b) { \
        S v = {0}; \
        for (size_t i = 0; i < a->len; i++) if (a->at[i].live && S##_has(b, LKOF(&a->at[i].key))) S##_insert(&v, LKOF(&a->at[i].key)); \
        return v; } \
    __attribute__((unused)) static inline S S##_difference(const S *a, const S *b) { \
        S v = {0}; \
        for (size_t i = 0; i < a->len; i++) if (a->at[i].live && !S##_has(b, LKOF(&a->at[i].key))) S##_insert(&v, LKOF(&a->at[i].key)); \
        return v; } \
    __attribute__((unused)) static inline S S##_symdiff(const S *a, const S *b) { \
        S v = S##_difference(a, b); \
        for (size_t i = 0; i < b->len; i++) if (b->at[i].live && !S##_has(a, LKOF(&b->at[i].key))) S##_insert(&v, LKOF(&b->at[i].key)); \
        return v; } \
    __attribute__((unused)) static inline void S##_intersect_with(S *s, const S *t) { S v = S##_intersection(s, t); S##_assign(s, v); } \
    __attribute__((unused)) static inline void S##_symdiff_with(S *s, const S *t) { S v = S##_symdiff(s, t); S##_assign(s, v); }

/* Dictionary<K, V> (#65): a hash map on the heap, its entries in the
   order they were added (dead ones skipped, compacted on growth), a
   chain per bucket, twice as many buckets as entries; the type alone
   first, so that a value may hold a Dictionary of its own type. K is
   the key kept (an integer, or a String of the text), LK the key given
   (the integer, or a cstr). */
#define KV_DICT_TYPE(D) \
    typedef struct D##_entry D##_entry; \
    typedef struct D { D##_entry *at; size_t count, len, cap; uint32_t *head; size_t hcap; } D;
#define KV_DICT(K, LK, V, D, HASH, EQ, STORE, MISSING, KFREE, KCOPY, VFREE, VCOPY) \
    KV_DICT_TYPE(D) KV_DICT_FUNCS(K, LK, V, D, HASH, EQ, STORE, MISSING, KFREE, KCOPY, VFREE, VCOPY)
#define KV_DICT_FUNCS(K, LK, V, D, HASH, EQ, STORE, MISSING, KFREE, KCOPY, VFREE, VCOPY) \
    struct D##_entry { K key; V value; size_t hash; uint32_t next; bool live; }; \
    __attribute__((unused)) static inline void D##_free(D *d) { \
        for (size_t i = 0; i < d->len; i++) if (d->at[i].live) { KFREE(&d->at[i].key); VFREE(&d->at[i].value); } \
        free(d->at); free(d->head); *d = (D){0}; } \
    __attribute__((unused)) static inline D D##_take(D *d) { D v = *d; *d = (D){0}; return v; } \
    __attribute__((unused)) static inline void D##_assign(D *d, D v) { D##_free(d); *d = v; } \
    __attribute__((unused)) static inline void D##_discard(D v) { D##_free(&v); } \
    __attribute__((unused)) static inline D##_entry *D##_lookup(const D *d, LK k, size_t h) { \
        if (!d->hcap) return NULL; \
        for (uint32_t i = d->head[h & (d->hcap - 1)]; i; i = d->at[i - 1].next) \
            if (d->at[i - 1].hash == h && EQ(&d->at[i - 1].key, k)) return &d->at[i - 1]; \
        return NULL; } \
    __attribute__((unused)) static inline void D##_link(D *d, size_t i) { \
        size_t b = d->at[i].hash & (d->hcap - 1); d->at[i].next = d->head[b]; d->head[b] = (uint32_t)(i + 1); } \
    __attribute__((unused)) static inline void D##_rehash(D *d, size_t cap) { \
        D##_entry *at = malloc(cap * sizeof *at); \
        uint32_t *head = malloc(cap * 2 * sizeof *head); \
        if (!at || !head) kv_array_fail("out of memory"); \
        memset(head, 0, cap * 2 * sizeof *head); \
        size_t n = 0; \
        for (size_t i = 0; i < d->len; i++) if (d->at[i].live) at[n++] = d->at[i]; \
        free(d->at); free(d->head); \
        d->at = at; d->len = n; d->cap = cap; d->head = head; d->hcap = cap * 2; \
        for (size_t i = 0; i < n; i++) D##_link(d, i); } \
    __attribute__((unused)) static inline void D##_reserve(D *d, size_t n) { \
        if (n <= d->cap) return; \
        size_t cap = d->cap ? d->cap : 16; \
        while (cap < n) cap *= 2; \
        D##_rehash(d, cap); } \
    __attribute__((unused)) static inline V *D##_find(const D *d, LK k) { \
        D##_entry *e = D##_lookup(d, k, HASH(k)); return e ? &e->value : NULL; } \
    __attribute__((unused)) static inline V *D##_at(const D *d, LK k) { \
        D##_entry *e = D##_lookup(d, k, HASH(k)); if (!e) MISSING(k); return &e->value; } \
    __attribute__((unused)) static inline bool D##_has(const D *d, LK k) { return D##_lookup(d, k, HASH(k)) != NULL; } \
    __attribute__((unused)) static inline V D##_get(const D *d, LK k, V v) { \
        D##_entry *e = D##_lookup(d, k, HASH(k)); return e ? e->value : v; } \
    __attribute__((unused)) static inline V *D##_set(D *d, LK k, V v) { \
        size_t h = HASH(k); \
        D##_entry *e = D##_lookup(d, k, h); \
        if (e) { VFREE(&e->value); e->value = v; return &e->value; } \
        if (d->len == d->cap) D##_rehash(d, !d->cap ? 16 : d->count + 1 > d->cap / 2 ? d->cap * 2 : d->cap); \
        e = &d->at[d->len++]; \
        e->key = STORE(k); e->value = v; e->hash = h; e->live = true; \
        D##_link(d, (size_t)(e - d->at)); d->count++; return &e->value; } \
    __attribute__((unused)) static inline bool D##_remove(D *d, LK k) { \
        if (!d->hcap) return false; \
        size_t h = HASH(k); \
        for (uint32_t *p = &d->head[h & (d->hcap - 1)]; *p; p = &d->at[*p - 1].next) { \
            D##_entry *e = &d->at[*p - 1]; \
            if (e->hash == h && EQ(&e->key, k)) { \
                *p = e->next; KFREE(&e->key); VFREE(&e->value); e->live = false; d->count--; return true; } } \
        return false; } \
    __attribute__((unused)) static inline void D##_clear(D *d) { \
        for (size_t i = 0; i < d->len; i++) if (d->at[i].live) { KFREE(&d->at[i].key); VFREE(&d->at[i].value); } \
        d->len = 0; d->count = 0; \
        if (d->head) memset(d->head, 0, d->hcap * sizeof *d->head); } \
    __attribute__((unused)) static inline D D##_copy(const D *d) { \
        D v = {0}; D##_reserve(&v, d->count); \
        for (size_t i = 0; i < d->len; i++) if (d->at[i].live) { \
            D##_entry *e = &v.at[v.len++]; \
            e->key = KCOPY(&d->at[i].key); e->value = VCOPY(&d->at[i].value); e->hash = d->at[i].hash; e->live = true; \
            D##_link(&v, (size_t)(e - v.at)); v.count++; } \
        return v; }
#define KV_PLAIN_FREE(p) ((void)(p))
#define KV_PLAIN_COPY(p) (*(p))
/* the type alone first, so that an element may hold an Array of its own
   type (#61); the functions follow the element's declaration */
#define KV_ARRAY_TYPE(T, A) \
    typedef T A##_elem; \
    typedef struct A { T *at; size_t count, cap; } A;
#define KV_ARRAY(T, A, FREE, COPY) KV_ARRAY_TYPE(T, A) KV_ARRAY_FUNCS(T, A, FREE, COPY)
#define KV_ARRAY_FUNCS(T, A, FREE, COPY) \
    __attribute__((unused)) static inline void A##_free(A *a) { \
        for (size_t i = 0; i < a->count; i++) FREE(&a->at[i]); \
        free(a->at); *a = (A){0}; } \
    __attribute__((unused)) static inline A A##_take(A *a) { A v = *a; *a = (A){0}; return v; } \
    __attribute__((unused)) static inline void A##_assign(A *a, A v) { A##_free(a); *a = v; } \
    __attribute__((unused)) static inline void A##_discard(A v) { A##_free(&v); } \
    __attribute__((unused)) static inline void A##_reserve(A *a, size_t n) { \
        if (n <= a->cap) return; \
        size_t cap = a->cap ? a->cap : 16; \
        while (cap < n) cap *= 2; \
        T *at = realloc(a->at, cap * sizeof *at); \
        if (!at) kv_array_fail("out of memory"); \
        a->at = at; a->cap = cap; } \
    __attribute__((unused)) static inline A A##_zeros(size_t n) { \
        A v = {0}; A##_reserve(&v, n); memset(v.at, 0, n * sizeof *v.at); v.count = n; return v; } \
    __attribute__((unused)) static inline A A##_from(const A##_elem *p, size_t n) { \
        A v = {0}; A##_reserve(&v, n); memcpy(v.at, p, n * sizeof *v.at); v.count = n; return v; } \
    __attribute__((unused)) static inline A A##_slice(const A *a, size_t lo, size_t hi) { \
        if (lo > hi || hi > a->count) kv_slice_range(lo, hi, a->count, "Array"); \
        A v = {0}; A##_reserve(&v, hi - lo); \
        for (size_t i = lo; i < hi; i++) v.at[v.count++] = COPY(&a->at[i]); \
        return v; } \
    __attribute__((unused)) static inline A A##_copy(const A *a) { \
        A v = {0}; A##_reserve(&v, a->count); \
        for (size_t i = 0; i < a->count; i++) v.at[i] = COPY(&a->at[i]); \
        v.count = a->count; return v; } \
    __attribute__((unused)) static inline void A##_append(A *a, T v) { A##_reserve(a, a->count + 1); a->at[a->count++] = v; } \
    __attribute__((unused)) static inline void A##_append_ref(A *a, const A *v) { \
        size_t n = v->count; A##_reserve(a, a->count + n); \
        for (size_t i = 0; i < n; i++) a->at[a->count + i] = COPY(&v->at[i]); \
        a->count += n; } \
    __attribute__((unused)) static inline void A##_append_owned(A *a, A v) { \
        A##_reserve(a, a->count + v.count); memmove(a->at + a->count, v.at, v.count * sizeof *a->at); \
        a->count += v.count; free(v.at); } \
    __attribute__((unused)) static inline T *A##_at(const A *a, size_t i) { if (i >= a->count) kv_array_range(i, a->count); return a->at + i; } \
    __attribute__((unused)) static inline T A##_pop(A *a) { if (!a->count) kv_array_fail("pop of an empty Array"); return a->at[--a->count]; } \
    __attribute__((unused)) static inline void A##_insert(A *a, size_t i, T v) { \
        if (i > a->count) kv_array_range(i, a->count); \
        A##_reserve(a, a->count + 1); \
        memmove(a->at + i + 1, a->at + i, (a->count - i) * sizeof *a->at); a->at[i] = v; a->count++; } \
    __attribute__((unused)) static inline void A##_remove(A *a, size_t i, size_t n) { \
        if (i > a->count || n > a->count - i) kv_array_range(i, a->count); \
        for (size_t k = i; k < i + n; k++) FREE(&a->at[k]); \
        memmove(a->at + i, a->at + i + n, (a->count - i - n) * sizeof *a->at); a->count -= n; } \
    __attribute__((unused)) static inline void A##_clear(A *a) { \
        for (size_t i = 0; i < a->count; i++) FREE(&a->at[i]); \
        a->count = 0; } \
    __attribute__((unused)) static inline void A##_compact(A *a) { \
        if (!a->at) return; \
        if (!a->count) { free(a->at); *a = (A){0}; return; } \
        T *at = realloc(a->at, a->count * sizeof *at); if (at) { a->at = at; a->cap = a->count; } }

/* Bytes(x): n zero bytes of a number, a copy of text or of a Bytes borrow */
#define KV_BYTES_OF(x) _Generic((x), \
    char: kv_bytes_zeros, signed char: kv_bytes_zeros, short: kv_bytes_zeros, int: kv_bytes_zeros, \
    long: kv_bytes_zeros, long long: kv_bytes_zeros, \
    unsigned char: kv_bytes_zeros, unsigned short: kv_bytes_zeros, unsigned: kv_bytes_zeros, \
    unsigned long: kv_bytes_zeros, unsigned long long: kv_bytes_zeros, \
    kv_bytes *: kv_bytes_copy, const kv_bytes *: kv_bytes_copy, \
    default: kv_bytes_text)(x)
/* b.append(x): a byte, text, a Bytes borrow, or a Bytes an expression gives, which is freed */
#define KV_BYTES_APPEND(b, x) _Generic((x), \
    char: kv_bytes_push, signed char: kv_bytes_push, short: kv_bytes_push, int: kv_bytes_push, \
    long: kv_bytes_push, long long: kv_bytes_push, \
    unsigned char: kv_bytes_push, unsigned short: kv_bytes_push, unsigned: kv_bytes_push, \
    unsigned long: kv_bytes_push, unsigned long long: kv_bytes_push, \
    kv_bytes: kv_bytes_append_owned, kv_bytes *: kv_bytes_append_ref, const kv_bytes *: kv_bytes_append_ref, \
    default: kv_bytes_append_text)((b), (x))
#define KV_BYTES_INSERT(b, i, x) _Generic((x), \
    char: kv_bytes_insert_byte, signed char: kv_bytes_insert_byte, short: kv_bytes_insert_byte, int: kv_bytes_insert_byte, \
    long: kv_bytes_insert_byte, long long: kv_bytes_insert_byte, \
    unsigned char: kv_bytes_insert_byte, unsigned short: kv_bytes_insert_byte, unsigned: kv_bytes_insert_byte, \
    unsigned long: kv_bytes_insert_byte, unsigned long long: kv_bytes_insert_byte, \
    kv_bytes: kv_bytes_insert_owned, kv_bytes *: kv_bytes_insert_ref, const kv_bytes *: kv_bytes_insert_ref, \
    default: kv_bytes_insert_text)((b), (i), (x))
uint8_t *kv_cstr_bool(bool v, uint8_t *buf);
uint8_t *kv_cstr_char(char v, uint8_t *buf);
uint8_t *kv_cstr_i64(long long v, uint8_t *buf);
uint8_t *kv_cstr_u64(unsigned long long v, uint8_t *buf);
uint8_t *kv_cstr_f32(float v, uint8_t *buf);
uint8_t *kv_cstr_f64(double v, uint8_t *buf);
uint8_t *kv_cstr_f80(long double v, uint8_t *buf);
uint8_t *kv_cstr_cf(float _Complex v, uint8_t *buf);
uint8_t *kv_cstr_cd(double _Complex v, uint8_t *buf);
uint8_t *kv_cstr_cld(long double _Complex v, uint8_t *buf);
uint8_t *kv_cstr_str(const char *v, uint8_t *buf);
const uint8_t *kv_cstr_cstr(const char *v, uint8_t *buf);
uint8_t *kv_cstr_ptr(const volatile void *v, uint8_t *buf);
/* v.typename (#34) for a type kelvinc cannot see: the Kelvin name of a
   built-in type, or "?". C's long is i64 or i32 by its size, which the
   compiler says without <limits.h> and its names. */
#if __SIZEOF_LONG__ == 8
#define KV_TYPENAME_LONG "i64"
#define KV_TYPENAME_ULONG "u64"
#else
#define KV_TYPENAME_LONG "i32"
#define KV_TYPENAME_ULONG "u32"
#endif
#ifdef __SIZEOF_INT128__
#define KV_TYPENAME_INT128 __int128: "i128", unsigned __int128: "u128",
#else
#define KV_TYPENAME_INT128
#endif
#define kv_typename(v) _Generic((v), \
    kv_bytes: "Bytes", kv_string: "String", kv_uchr: "uchr", \
    bool: "bool", char: "u8", signed char: "i8", short: "i16", int: "i32", \
    long: KV_TYPENAME_LONG, long long: "i64", \
    unsigned char: "u8", unsigned short: "u16", unsigned: "u32", \
    unsigned long: KV_TYPENAME_ULONG, unsigned long long: "u64", \
    KV_TYPENAME_INT128 \
    float: "f32", double: "f64", float _Complex: "f32 _Complex", double _Complex: "f64 _Complex", \
    char *: "u8^", const char *: "const u8^", unsigned char *: "u8^", const unsigned char *: "const u8^", \
    signed char *: "i8^", const signed char *: "const i8^", void *: "any^", const void *: "const any^", \
    default: "?")

#ifdef __SIZEOF_INT128__
uint8_t *kv_cstr_i128(__int128 v, uint8_t *buf);
uint8_t *kv_cstr_u128(unsigned __int128 v, uint8_t *buf);
#define KV_INT128_cstr __int128: kv_cstr_i128, unsigned __int128: kv_cstr_u128,
#else
#define KV_INT128_cstr
#endif

/* kelvinc turns `v.cstr` into
   _Generic((v), KV_PROPERTY_cstr <Kelvin structs> default: kv_cstr_ptr)(v, buf).
   C's own type names are listed rather than int64_t and friends, because
   int64_t is `long` on some platforms and `long long` on others, and a
   _Generic list may not name the same type twice. */
#define KV_PROPERTY_cstr \
    kv_bytes: kv_cstr_bytes, kv_string: kv_cstr_string, kv_uchr: kv_cstr_uchr, \
    bool: kv_cstr_bool, char: kv_cstr_char, \
    signed char: kv_cstr_i64, short: kv_cstr_i64, int: kv_cstr_i64, \
    long: kv_cstr_i64, long long: kv_cstr_i64, \
    unsigned char: kv_cstr_u64, unsigned short: kv_cstr_u64, unsigned: kv_cstr_u64, \
    unsigned long: kv_cstr_u64, unsigned long long: kv_cstr_u64, \
    KV_INT128_cstr \
    float: kv_cstr_f32, double: kv_cstr_f64, long double: kv_cstr_f80, \
    float _Complex: kv_cstr_cf, double _Complex: kv_cstr_cd, \
    long double _Complex: kv_cstr_cld, \
    char *: kv_cstr_str, const char *: kv_cstr_cstr, \
    signed char *: kv_cstr_str, const signed char *: kv_cstr_cstr, \
    unsigned char *: kv_cstr_str, const unsigned char *: kv_cstr_cstr,

/* Selected for a Kelvin struct where kelvinc could not see the value's
   type, as in (c ? p : q).cstr, and so could not size the buffer for it;
   any call is a C type error that names this function. Assign the value
   to a variable first. */
struct kv_cstr_unseen_struct { char unused; };
uint8_t *kv_cstr_unseen_struct(struct kv_cstr_unseen_struct, uint8_t *);

/* For the derived text of structs: each writes at p and returns the end.
   A string inside a struct shows at most KV_CSTR_STR bytes; a longer one
   is cut and ends in "...". */
#define KV_CSTR_STR 60
uint8_t *kv_cstr_end(uint8_t *s);
uint8_t *kv_cstr_put(uint8_t *p, const char *text);
uint8_t *kv_cstr_put_str(uint8_t *p, const char *s);
uint8_t *kv_cstr_put_text(uint8_t *p, const void *s);
uint8_t *kv_cstr_put_address(uint8_t *p, const volatile void *v);

/* A pointer member whose type kelvinc cannot tell is text, such as
   xmlChar^ or uint8_t^: byte strings are text, other pointers addresses */
#define kv_cstr_put_pointer(p, lv) _Generic((lv), \
    char *: kv_cstr_put_text, const char *: kv_cstr_put_text, \
    signed char *: kv_cstr_put_text, const signed char *: kv_cstr_put_text, \
    unsigned char *: kv_cstr_put_text, const unsigned char *: kv_cstr_put_text, \
    default: kv_cstr_put_address)(p, lv)

/* ---------- properties: x.dec, x.hex, x.oct, x.bin (#21) ---------- */

/* The text of a number, written into `buf` (a buffer on the caller's
   stack that kelvinc sizes for the longest text) and returned as u8^. Signed
   integers always carry a sign ("+42", "-0x2a"), which tells them from
   unsigned ones ("42", "0x2a"). Prefixes are 0x, 0o and 0b. f32/f64 have
   .dec (%.17g style) and .hex (%a), always signed. */
uint8_t *kv_dec_signed(long long v, uint8_t *buf);
uint8_t *kv_dec_unsigned(unsigned long long v, uint8_t *buf);
uint8_t *kv_dec_char(char v, uint8_t *buf);
uint8_t *kv_dec_f32(float v, uint8_t *buf);
uint8_t *kv_dec_f64(double v, uint8_t *buf);
uint8_t *kv_hex_signed(long long v, uint8_t *buf);
uint8_t *kv_hex_unsigned(unsigned long long v, uint8_t *buf);
uint8_t *kv_hex_char(char v, uint8_t *buf);
uint8_t *kv_hex_f32(float v, uint8_t *buf);
uint8_t *kv_hex_f64(double v, uint8_t *buf);
uint8_t *kv_oct_signed(long long v, uint8_t *buf);
uint8_t *kv_oct_unsigned(unsigned long long v, uint8_t *buf);
uint8_t *kv_oct_char(char v, uint8_t *buf);
uint8_t *kv_bin_signed(long long v, uint8_t *buf);
uint8_t *kv_bin_unsigned(unsigned long long v, uint8_t *buf);
uint8_t *kv_bin_char(char v, uint8_t *buf);
#ifdef __SIZEOF_INT128__
uint8_t *kv_dec_i128(__int128 v, uint8_t *buf);
uint8_t *kv_dec_u128(unsigned __int128 v, uint8_t *buf);
uint8_t *kv_hex_i128(__int128 v, uint8_t *buf);
uint8_t *kv_hex_u128(unsigned __int128 v, uint8_t *buf);
uint8_t *kv_oct_i128(__int128 v, uint8_t *buf);
uint8_t *kv_oct_u128(unsigned __int128 v, uint8_t *buf);
uint8_t *kv_bin_i128(__int128 v, uint8_t *buf);
uint8_t *kv_bin_u128(unsigned __int128 v, uint8_t *buf);
#define KV_INT128_PROPERTY(p) __int128: kv_##p##_i128, unsigned __int128: kv_##p##_u128,
#else
#define KV_INT128_PROPERTY(p)
#endif

#define KV_INT_PROPERTY(p) \
    char: kv_##p##_char, \
    signed char: kv_##p##_signed, short: kv_##p##_signed, int: kv_##p##_signed, \
    long: kv_##p##_signed, long long: kv_##p##_signed, \
    unsigned char: kv_##p##_unsigned, unsigned short: kv_##p##_unsigned, unsigned: kv_##p##_unsigned, \
    unsigned long: kv_##p##_unsigned, unsigned long long: kv_##p##_unsigned, \
    KV_INT128_PROPERTY(p)

#define KV_PROPERTY_dec KV_INT_PROPERTY(dec) float: kv_dec_f32, double: kv_dec_f64,
#define KV_PROPERTY_hex KV_INT_PROPERTY(hex) float: kv_hex_f32, double: kv_hex_f64,
#define KV_PROPERTY_oct KV_INT_PROPERTY(oct)
#define KV_PROPERTY_bin KV_INT_PROPERTY(bin)

/* Selected when a type has no such property. Its parameter is a struct
   that nothing else has, taken by value, so any call is a C type error
   that names this function, also with a pointer, which a pointer
   parameter would only warn about. */
struct kv_no_such_property { char unused; };
uint8_t *kv_no_such_property(struct kv_no_such_property, uint8_t *);

/* p.hex of a pointer or a function (#37): 0x and all the digits of its
   address, 16 on a 64-bit target, as in 0x000000016ee86888. Where
   kelvinc cannot see that a value is a pointer, KV_HEX_DEFAULT picks
   kv_hex_ptr for any pointer, by GCC's and clang's
   __builtin_classify_type (5 is a pointer), and kv_no_such_property for
   anything else. */
uint8_t *kv_hex_addr(uintptr_t v, uint8_t *buf);
uint8_t *kv_hex_ptr(const volatile void *p, uint8_t *buf);
#define KV_HEX_DEFAULT(v) __builtin_choose_expr(__builtin_classify_type(v) == 5, kv_hex_ptr, kv_no_such_property)

/* Conditions are bool (#23). Where kelvinc cannot see a condition's
   type, it emits _Generic((c), bool: kv_bool, default:
   kv_condition_is_not_bool)(c): a bool passes through, and anything else
   is a C type error that names kv_condition_is_not_bool. */
static inline bool kv_bool(bool b) { return b; }
struct kv_condition_is_not_bool { char unused; };
bool kv_condition_is_not_bool(struct kv_condition_is_not_bool);

/* Selected when a type has no such method; any call is a C type error
   that names this function, as above. */
struct kv_no_such_method { char unused; };
void kv_no_such_method(struct kv_no_such_method);

/* The Kelvin number type of a value whose type only C sees, for choosing
   an overload (#41): long and long long are both i64 where they have 64
   bits, char is u8, an enum is its integer type, and anything else 0.
   An integer constant, as _Generic does not evaluate v. */
enum {
    KV_N_BOOL = 1, KV_N_I8, KV_N_U8, KV_N_I16, KV_N_U16, KV_N_I32, KV_N_U32, KV_N_I64, KV_N_U64,
    KV_N_I128, KV_N_U128, KV_N_F32, KV_N_F64, KV_N_F80,
};
#ifdef __SIZEOF_INT128__
#define KV_INT128_NUMBER __int128: KV_N_I128, unsigned __int128: KV_N_U128,
#else
#define KV_INT128_NUMBER
#endif
#define KV_NUMBER(v) _Generic((v), \
    bool: KV_N_BOOL, char: KV_N_U8, signed char: KV_N_I8, unsigned char: KV_N_U8, \
    short: KV_N_I16, unsigned short: KV_N_U16, int: KV_N_I32, unsigned int: KV_N_U32, \
    long: (sizeof(long) == 8 ? KV_N_I64 : KV_N_I32), unsigned long: (sizeof(long) == 8 ? KV_N_U64 : KV_N_U32), \
    long long: KV_N_I64, unsigned long long: KV_N_U64, KV_INT128_NUMBER \
    float: KV_N_F32, double: KV_N_F64, long double: KV_N_F80, default: 0)
#define KV_POINTER(v) (__builtin_classify_type(v) == 5)

/* Selected when a value whose type only C sees is a number of a type
   that no overload takes (#41) while several take other numbers, or
   when no operator a struct defines takes it (#42); any use is a C type
   error that names it, as above. */
struct kv_no_such_overload { char unused; };
void kv_no_such_overload(struct kv_no_such_overload, ...);
struct kv_no_such_operator { char unused; };
void kv_no_such_operator(struct kv_no_such_operator, ...);

/* The text of a struct member whose type kelvinc cannot see, such as a
   C typedef: numbers, bool and complex numbers as .cstr gives them, byte
   strings as text, a char array (typedef char name_t[16]) as the text
   in it, void * as an address, anything else "{...}" (a struct, an array
   of other things, a pointer to anything else). At most
   KV_CSTR_SCALAR - 1 bytes. _Generic sees an array as a pointer, so
   the type of &(lv) tells a char array from a char *. */
enum {
    KV_K_OPAQUE, KV_K_BOOL, KV_K_CHAR, KV_K_SCHAR, KV_K_UCHAR, KV_K_SHORT, KV_K_USHORT, KV_K_INT,
    KV_K_UINT, KV_K_LONG, KV_K_ULONG, KV_K_LLONG, KV_K_ULLONG, KV_K_I128, KV_K_U128, KV_K_FLOAT,
    KV_K_DOUBLE, KV_K_LDOUBLE, KV_K_STR, KV_K_CHARS, KV_K_PTR, KV_K_CF, KV_K_CD, KV_K_CLD,
};
uint8_t *kv_cstr_kind(const void *p, int kind, size_t size, uint8_t *buf);
#ifdef __SIZEOF_INT128__
#define KV_INT128_KIND __int128: KV_K_I128, unsigned __int128: KV_K_U128,
#else
#define KV_INT128_KIND
#endif
#define kv_cstr_any(lv, buf) kv_cstr_kind((const void *)&(lv), _Generic((lv), \
    bool: KV_K_BOOL, char: KV_K_CHAR, signed char: KV_K_SCHAR, unsigned char: KV_K_UCHAR, \
    short: KV_K_SHORT, unsigned short: KV_K_USHORT, int: KV_K_INT, unsigned: KV_K_UINT, \
    long: KV_K_LONG, unsigned long: KV_K_ULONG, long long: KV_K_LLONG, \
    unsigned long long: KV_K_ULLONG, KV_INT128_KIND \
    float: KV_K_FLOAT, double: KV_K_DOUBLE, long double: KV_K_LDOUBLE, \
    float _Complex: KV_K_CF, double _Complex: KV_K_CD, long double _Complex: KV_K_CLD, \
    char *: _Generic(&(lv), char (*)[sizeof(lv)]: KV_K_CHARS, default: KV_K_STR), \
    const char *: _Generic(&(lv), const char (*)[sizeof(lv)]: KV_K_CHARS, default: KV_K_STR), \
    signed char *: _Generic(&(lv), signed char (*)[sizeof(lv)]: KV_K_OPAQUE, default: KV_K_STR), \
    const signed char *: _Generic(&(lv), const signed char (*)[sizeof(lv)]: KV_K_OPAQUE, default: KV_K_STR), \
    unsigned char *: _Generic(&(lv), unsigned char (*)[sizeof(lv)]: KV_K_OPAQUE, default: KV_K_STR), \
    const unsigned char *: _Generic(&(lv), const unsigned char (*)[sizeof(lv)]: KV_K_OPAQUE, default: KV_K_STR), \
    void *: KV_K_PTR, const void *: KV_K_PTR, \
    default: KV_K_OPAQUE), sizeof(lv), buf)

/* ---------- print ---------- */

void kv_print_char(char v);
void kv_print_i64(long long v);
void kv_print_u64(unsigned long long v);
void kv_print_f32(float v);
void kv_print_f64(double v);
void kv_print_f80(long double v);
void kv_print_bool(bool v);
void kv_print_str(const char *v);
void kv_print_ptr(const void *v);
void kv_print_newline(void);
#ifdef __SIZEOF_INT128__
void kv_print_i128(__int128 v);
void kv_print_u128(unsigned __int128 v);
#define KV_PRINT_INT128 __int128: kv_print_i128, unsigned __int128: kv_print_u128,
#else
#define KV_PRINT_INT128
#endif

#define kv_print1(v) _Generic((v), \
    kv_bytes: kv_print_bytes, kv_string: kv_print_string, kv_uchr: kv_print_uchr, \
    bool: kv_print_bool, \
    char: kv_print_char, \
    signed char: kv_print_i64, short: kv_print_i64, int: kv_print_i64, \
    long: kv_print_i64, long long: kv_print_i64, \
    unsigned char: kv_print_u64, unsigned short: kv_print_u64, unsigned: kv_print_u64, \
    unsigned long: kv_print_u64, unsigned long long: kv_print_u64, \
    KV_PRINT_INT128 \
    float: kv_print_f32, double: kv_print_f64, long double: kv_print_f80, \
    char *: kv_print_str, const char *: kv_print_str, \
    signed char *: kv_print_str, const signed char *: kv_print_str, \
    unsigned char *: kv_print_str, const unsigned char *: kv_print_str, \
    default: kv_print_ptr)(v)

/* ---------- numbers from text: i64("42"), "42".i64 (#36) ---------- */

/* The integer at the start of text, read as C's strtol reads it: leading
   spaces, a sign, then digits in base 2 to 36 (Kelvin's 0x, 0o and 0b may
   come first in base 16, 8 and 2). No number is 0, and so is a NULL text
   or a base outside 2 to 36. A number out of the type's range is clamped
   to its limits (an unsigned type's lowest is 0), and errno is then
   ERANGE; otherwise errno is left alone. Floats are strtod's and strtof's
   own: out of range is an infinity, and errno is ERANGE also when the
   result is tiny, as C sets it. */
int64_t kv_text_int(const void *text, long long base, int64_t min, int64_t max);
uint64_t kv_text_uint(const void *text, long long base, uint64_t max);
double kv_text_f64(const void *text);
float kv_text_f32(const void *text);
#ifdef __SIZEOF_INT128__
__int128 kv_text_i128(const void *text, long long base);
unsigned __int128 kv_text_u128(const void *text, long long base);
#endif

/* Where kelvinc cannot see whether a value is text, _Generic tells:
   char *, signed char * and unsigned char * (u8^, i8^), const or not, are
   read, and anything else is converted as C's cast converts it.
   KV_TEXT(T, v, read) is read, an expression that reads KV_TEXT_PTR(v),
   for text, and v converted to T otherwise. Inside a function, kelvinc
   puts v in a temporary first, so that v is evaluated and written once;
   at file scope, KV_TEXT stays a constant expression for numbers. With a
   base, the text is required: anything else is a C type error that names
   kv_base_needs_text. */
typedef struct kv_text_tag kv_text_tag;
#define KV_TEXT_TAG(v)                                                                                        \
    _Generic((v), char *: (kv_text_tag *)0, const char *: (kv_text_tag *)0, signed char *: (kv_text_tag *)0, \
             const signed char *: (kv_text_tag *)0, unsigned char *: (kv_text_tag *)0,                       \
             const unsigned char *: (kv_text_tag *)0, default: 0)
#define KV_TEXT_PTR(v) _Generic(KV_TEXT_TAG(v), kv_text_tag *: (v), default: (const void *)0)
#define KV_NOT_TEXT(v) _Generic(KV_TEXT_TAG(v), kv_text_tag *: 0, default: (v))
#define KV_TEXT(T, v, read) _Generic(KV_TEXT_TAG(v), kv_text_tag *: (T)(read), default: (T)(KV_NOT_TEXT(v)))
struct kv_base_needs_text { char unused; };
void kv_base_needs_text(struct kv_base_needs_text, ...);

/* ---------- template literals (#39) ---------- */

/* `a${x}b` has storage that kelvinc declares at the top of the enclosing
   block, `char _kv_template0[N];`, as it does a text property's buffer:
   no heap, no cleanup, and a switch or goto may jump past it. N is a
   constant that C computes: the literal parts, a NUL, and the longest
   text of each value (by the type kelvinc sees, or KV_TEMPLATE_STR). The
   text lives until the block ends.

   Each evaluation builds the text in a buffer of its own statement
   expression (KV_TEMPLATE_BUILD), from the parts and each value in turn,
   as before, then copies it into the storage (KV_TEMPLATE_TAKE), so a
   value may read the earlier text, as in s := `${s}b`.

   A string value shows at most KV_TEMPLATE_STR bytes; a longer one is
   cut and ends in "...". A program may change it with
   KELVIN_CFLAGS=-DKV_TEMPLATE_STR=n; libkelvin needs no rebuild, since
   kelvinc passes each value's limit to the writers. */
#ifndef KV_TEMPLATE_STR
#define KV_TEMPLATE_STR 256
#endif
#if KV_TEMPLATE_STR < 64
#error "KV_TEMPLATE_STR must be at least 64, the longest text of any value but a string"
#endif

/* each writer puts at most max bytes at p and returns the end */
char *kv_template_part(char *p, const char *s, size_t n);
char *kv_template_char(char *p, size_t max, char v);
char *kv_template_i64(char *p, size_t max, long long v);
char *kv_template_u64(char *p, size_t max, unsigned long long v);
char *kv_template_bool(char *p, size_t max, bool v);
char *kv_template_str(char *p, size_t max, const char *v);
char *kv_template_bytes(char *p, size_t max, size_t n, const void *v);
char *kv_template_ptr(char *p, size_t max, const void *v);
char *kv_template_f64(char *p, size_t max, double v);
char *kv_template_f32(char *p, size_t max, float v);
char *kv_template_f80(char *p, size_t max, long double v);
/* copies the text built in another buffer into the storage, ends it
   with a NUL and returns it */
char *kv_template_copy(char *storage, const char *built, const char *end);
#ifdef __SIZEOF_INT128__
char *kv_template_u128(char *p, size_t max, unsigned __int128 v);
char *kv_template_i128(char *p, size_t max, __int128 v);
#define KV_TEMPLATE_INT128 __int128: kv_template_i128, unsigned __int128: kv_template_u128,
#define KV_TEMPLATE_INT128_BOUND __int128: 40, unsigned __int128: 39,
#else
#define KV_TEMPLATE_INT128
#define KV_TEMPLATE_INT128_BOUND
#endif
/* The longest text of a value of v's type, as print shows it; 0 for a
   string, which is cut at the limit given. long double is 44 at most
   (36 digits and a 4-digit exponent, IEEE quad); a pointer is 0x and
   its digits ("(nil)" on glibc is shorter). */
#define KV_TEMPLATE_BOUND(v) _Generic((v), \
    kv_uchr: 4, kv_bytes: 0, kv_string: 0, \
    bool: 5, char: 1, \
    signed char: 4, short: 6, int: 11, long: 20, long long: 20, \
    unsigned char: 3, unsigned short: 5, unsigned: 10, unsigned long: 20, unsigned long long: 20, \
    KV_TEMPLATE_INT128_BOUND \
    float: 15, double: 24, long double: 44, \
    char *: 0, const char *: 0, signed char *: 0, const signed char *: 0, \
    unsigned char *: 0, const unsigned char *: 0, \
    default: sizeof(void *) * 2 + 2)
/* `p = writer(p, max, v);` after checking, at compile time, that the
   value's type has no longer text than the max kelvinc gave it */
#define KV_TEMPLATE_VALUE(b, max, v) \
    _Static_assert(KV_TEMPLATE_BOUND(v) <= (max), "kelvinc left too little room for a template's value"); \
    (b).at = _Generic((v), \
    bool: kv_template_bool, \
    char: kv_template_char, \
    signed char: kv_template_i64, short: kv_template_i64, int: kv_template_i64, \
    long: kv_template_i64, long long: kv_template_i64, \
    unsigned char: kv_template_u64, unsigned short: kv_template_u64, unsigned: kv_template_u64, \
    unsigned long: kv_template_u64, unsigned long long: kv_template_u64, \
    KV_TEMPLATE_INT128 \
    float: kv_template_f32, double: kv_template_f64, long double: kv_template_f80, \
    char *: kv_template_str, const char *: kv_template_str, \
    signed char *: kv_template_str, const signed char *: kv_template_str, \
    unsigned char *: kv_template_str, const unsigned char *: kv_template_str, \
    kv_bytes: kv_template_bytes_owner, kv_string: kv_template_string, kv_uchr: kv_template_uchr, \
    default: kv_template_ptr)((b).at, (max), (v))
/* a buffer the size of the storage, and where the text built in it ends */
#define KV_TEMPLATE_BUILD(b, storage) \
    struct { char *at, text[sizeof (storage)]; } b; \
    (b).at = (b).text
#define KV_TEMPLATE_PART(b, s) ((b).at = kv_template_part((b).at, s, sizeof s - 1))
/* a byte array of n bytes: the text up to a NUL or its end, cut at max
   as a string is */
#define KV_TEMPLATE_BYTES(b, max, n, v) ((b).at = kv_template_bytes((b).at, (max), (n), (v)))
#define KV_TEMPLATE_TAKE(storage, b) kv_template_copy((storage), (b).text, (b).at)

#define KV_CAT_(a, b) a##b
#define KV_CAT(a, b) KV_CAT_(a, b)
/* __VA_OPT__ (C23, accepted by gcc and clang in C11 mode as well) lets
   print() and println() take no values */
#define KV_NARGS(...) KV_NARGS_(0 __VA_OPT__(,) __VA_ARGS__, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0)
#define KV_NARGS_(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, n, ...) n

#define kv_print_n0() ((void)0)
#define kv_print_n1(a) kv_print1(a)
#define kv_print_n2(a, ...) (kv_print1(a), kv_print_n1(__VA_ARGS__))
#define kv_print_n3(a, ...) (kv_print1(a), kv_print_n2(__VA_ARGS__))
#define kv_print_n4(a, ...) (kv_print1(a), kv_print_n3(__VA_ARGS__))
#define kv_print_n5(a, ...) (kv_print1(a), kv_print_n4(__VA_ARGS__))
#define kv_print_n6(a, ...) (kv_print1(a), kv_print_n5(__VA_ARGS__))
#define kv_print_n7(a, ...) (kv_print1(a), kv_print_n6(__VA_ARGS__))
#define kv_print_n8(a, ...) (kv_print1(a), kv_print_n7(__VA_ARGS__))
#define kv_print_n9(a, ...) (kv_print1(a), kv_print_n8(__VA_ARGS__))
#define kv_print_n10(a, ...) (kv_print1(a), kv_print_n9(__VA_ARGS__))
#define kv_print_n11(a, ...) (kv_print1(a), kv_print_n10(__VA_ARGS__))
#define kv_print_n12(a, ...) (kv_print1(a), kv_print_n11(__VA_ARGS__))
#define kv_print_n13(a, ...) (kv_print1(a), kv_print_n12(__VA_ARGS__))
#define kv_print_n14(a, ...) (kv_print1(a), kv_print_n13(__VA_ARGS__))
#define kv_print_n15(a, ...) (kv_print1(a), kv_print_n14(__VA_ARGS__))
#define kv_print_n16(a, ...) (kv_print1(a), kv_print_n15(__VA_ARGS__))

#define print(...) KV_CAT(kv_print_n, KV_NARGS(__VA_ARGS__))(__VA_ARGS__)
#define println(...) (print(__VA_ARGS__), kv_print_newline())

#endif
