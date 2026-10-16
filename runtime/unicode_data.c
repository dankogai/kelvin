/* unicode_data.c - libkUnicodeData (#156): normalization (UAX #15), grapheme
   clusters (UAX #29), case mappings, categories and names, on the tables of
   unicode_tables.c and unicode_names.c */
#include "kelvin_prelude.h"
#include "kUnicodeData.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------- codepoints in and out ---------- */

typedef struct { uint32_t *at; size_t n, cap; } cps;

static void cps_push(cps *v, uint32_t c) {
    if (v->n == v->cap) {
        v->cap = v->cap ? v->cap * 2 : 64;
        v->at = realloc(v->at, v->cap * sizeof *v->at);
        if (!v->at) {
            fputs("kelvin: out of memory\n", stderr);
            exit(1);
        }
    }
    v->at[v->n++] = c;
}

static void decode(const kv_string *s, cps *v) {
    const uint8_t *p = kv_bytes_cstr(&s->b), *end = p + s->b.count;
    while (p < end)
        cps_push(v, kv_utf8_next(&p));
}

static kv_string encode(const cps *v) {
    kv_string s = kv_string_new();
    for (size_t i = 0; i < v->n; i++)
        kv_string_append_cp(&s, v->at[i]);
    return s;
}

/* ---------- lookups ---------- */

static const kv_ud_decomp *decomp_of(uint32_t cp) {
    size_t lo = 0, hi = kv_ud_decomp_count;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        if (kv_ud_decomps[mid].cp < cp)
            lo = mid + 1;
        else
            hi = mid;
    }
    return lo < kv_ud_decomp_count && kv_ud_decomps[lo].cp == cp ? &kv_ud_decomps[lo] : NULL;
}

static uint32_t mapped(const kv_ud_map *m, size_t n, uint32_t cp) {
    size_t lo = 0, hi = n;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        if (m[mid].from < cp)
            lo = mid + 1;
        else
            hi = mid;
    }
    return lo < n && m[lo].from == cp ? m[lo].to : cp;
}

uint32_t ucd_to_upper(uint32_t cp) { return mapped(kv_ud_upper, kv_ud_upper_count, cp); }
uint32_t ucd_to_lower(uint32_t cp) { return mapped(kv_ud_lower, kv_ud_lower_count, cp); }
uint32_t ucd_to_fold(uint32_t cp) { return mapped(kv_ud_fold, kv_ud_fold_count, cp); }

/* ---------- normalization (UAX #15) ---------- */

enum { SBase = 0xAC00, LBase = 0x1100, VBase = 0x1161, TBase = 0x11A7, LCount = 19, VCount = 21, TCount = 28,
       NCount = VCount * TCount, SCount = LCount * NCount };

static void decompose(uint32_t cp, bool compat, cps *out) {
    if (cp >= SBase && cp < SBase + SCount) { /* a Hangul syllable, by arithmetic */
        uint32_t s = cp - SBase;
        cps_push(out, LBase + s / NCount);
        cps_push(out, VBase + (s % NCount) / TCount);
        if (s % TCount)
            cps_push(out, TBase + s % TCount);
        return;
    }
    const kv_ud_decomp *d = decomp_of(cp);
    if (!d || (d->compat && !compat)) {
        cps_push(out, cp);
        return;
    }
    for (int i = 0; i < d->len; i++)
        decompose(kv_ud_decomp_pool[d->offset + i], compat, out);
}

/* the canonical ordering: each run of marks sorted by their class, stably */
static void reorder(cps *v) {
    for (size_t i = 1; i < v->n; i++) {
        uint8_t c = kv_ud_ccc(v->at[i]);
        if (c == 0)
            continue;
        size_t j = i;
        while (j > 0) {
            uint8_t b = kv_ud_ccc(v->at[j - 1]);
            if (b == 0 || b <= c)
                break;
            uint32_t t = v->at[j - 1];
            v->at[j - 1] = v->at[j];
            v->at[j] = t;
            j--;
        }
    }
}

static uint32_t compose_pair(uint32_t a, uint32_t b) {
    if (a >= LBase && a < LBase + LCount && b >= VBase && b < VBase + VCount) /* L + V */
        return SBase + ((a - LBase) * VCount + (b - VBase)) * TCount;
    if (a >= SBase && a < SBase + SCount && (a - SBase) % TCount == 0 && b > TBase && b < TBase + TCount) /* LV + T */
        return a + (b - TBase);
    size_t lo = 0, hi = kv_ud_pair_count;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        const kv_ud_pair *p = &kv_ud_pairs[mid];
        if (p->first < a || (p->first == a && p->second < b))
            lo = mid + 1;
        else
            hi = mid;
    }
    if (lo < kv_ud_pair_count && kv_ud_pairs[lo].first == a && kv_ud_pairs[lo].second == b)
        return kv_ud_pairs[lo].composed;
    return 0;
}

static void compose(cps *v) {
    if (v->n == 0)
        return;
    size_t starter = 0, out = 1;
    uint8_t last = kv_ud_ccc(v->at[0]);
    if (last != 0)
        last = 255; /* no starter yet: nothing composes with it */
    for (size_t i = 1; i < v->n; i++) {
        uint32_t c = v->at[i];
        uint8_t cc = kv_ud_ccc(c);
        uint32_t composite = compose_pair(v->at[starter], c);
        if (composite && (last < cc || last == 0)) {
            v->at[starter] = composite;
            continue;
        }
        if (cc == 0)
            starter = out;
        last = cc;
        v->at[out++] = c;
    }
    v->n = out;
}

kv_string ucd_normalize(const kv_string *s, int form) {
    cps in = {0}, out = {0};
    decode(s, &in);
    bool compat = form == KV_UD_NFKC || form == KV_UD_NFKD;
    for (size_t i = 0; i < in.n; i++)
        decompose(in.at[i], compat, &out);
    reorder(&out);
    if (form == KV_UD_NFC || form == KV_UD_NFKC)
        compose(&out);
    kv_string r = encode(&out);
    free(in.at);
    free(out.at);
    return r;
}

kv_string ucd_decomposition(uint32_t cp, bool compat) {
    cps out = {0};
    decompose(cp, compat, &out);
    kv_string r = kv_string_new();
    if (!(out.n == 1 && out.at[0] == cp))
        r = encode(&out);
    free(out.at);
    return r;
}

/* ---------- grapheme clusters (UAX #29) ---------- */

/* the bytes of the first cluster at p: the rules GB3 to GB13 and GB999, with
   the emoji sequences of GB11, the regional indicator pairs of GB12 and GB13
   and the Indic conjuncts of GB9c */
size_t ucd_grapheme_len(const uint8_t *p, size_t n) {
    if (n == 0)
        return 0;
    const uint8_t *q = p, *end = p + n;
    uint32_t prev = kv_utf8_next(&q);
    uint8_t pg = kv_ud_gcb(prev);
    int ri = pg == KV_GCB_RI ? 1 : 0;
    /* GB11: a pictograph, then Extend*, then ZWJ, joins the next pictograph */
    int emoji = pg == KV_GCB_PICTOGRAPHIC ? 1 : 0; /* 1 pictograph seen, 2 ZWJ after it */
    /* GB9c, as Unicode 16 has it: a linker, then (Extend|Linker)*, joins a consonant */
    int incb = kv_ud_incb(prev) == 3 ? 2 : 0; /* 2 a linker seen */
    while (q < end) {
        const uint8_t *at = q;
        uint32_t c = kv_utf8_next(&q);
        uint8_t g = kv_ud_gcb(c);
        bool join;
        if (pg == KV_GCB_CR && g == KV_GCB_LF)
            join = true; /* GB3 */
        else if (pg == KV_GCB_CONTROL || pg == KV_GCB_CR || pg == KV_GCB_LF)
            join = false; /* GB4 */
        else if (g == KV_GCB_CONTROL || g == KV_GCB_CR || g == KV_GCB_LF)
            join = false; /* GB5 */
        else if (pg == KV_GCB_L && (g == KV_GCB_L || g == KV_GCB_V || g == KV_GCB_LV || g == KV_GCB_LVT))
            join = true; /* GB6 */
        else if ((pg == KV_GCB_LV || pg == KV_GCB_V) && (g == KV_GCB_V || g == KV_GCB_T))
            join = true; /* GB7 */
        else if ((pg == KV_GCB_LVT || pg == KV_GCB_T) && g == KV_GCB_T)
            join = true; /* GB8 */
        else if (g == KV_GCB_EXTEND || g == KV_GCB_ZWJ)
            join = true; /* GB9 */
        else if (g == KV_GCB_SPACINGMARK)
            join = true; /* GB9a */
        else if (pg == KV_GCB_PREPEND)
            join = true; /* GB9b */
        else if (incb == 2 && kv_ud_incb(c) == 1)
            join = true; /* GB9c */
        else if (emoji == 2 && g == KV_GCB_PICTOGRAPHIC)
            join = true; /* GB11 */
        else if (pg == KV_GCB_RI && g == KV_GCB_RI && ri % 2 == 1)
            join = true; /* GB12, GB13 */
        else
            join = false; /* GB999 */
        if (!join)
            return (size_t)(at - p);
        /* the states after c */
        if (g == KV_GCB_RI)
            ri++;
        else
            ri = 0;
        if (g == KV_GCB_PICTOGRAPHIC)
            emoji = 1;
        else if (emoji == 1 && g == KV_GCB_ZWJ)
            emoji = 2;
        else if (emoji == 1 && g == KV_GCB_EXTEND)
            emoji = 1;
        else
            emoji = 0;
        uint8_t ic = kv_ud_incb(c);
        if (ic == 3)
            incb = 2;
        else if (!(incb == 2 && ic == 2)) /* an Extend keeps the state */
            incb = 0;
        prev = c;
        pg = g;
    }
    (void)prev;
    return n;
}

void ucd_graphemes(const kv_string *s, kv_string **out, size_t *count) {
    const uint8_t *p = kv_bytes_cstr(&s->b);
    size_t n = s->b.count, cap = 16, k = 0;
    kv_string *at = malloc(cap * sizeof *at);
    if (!at) {
        fputs("kelvin: out of memory\n", stderr);
        exit(1);
    }
    while (n > 0) {
        size_t len = ucd_grapheme_len(p, n);
        if (k == cap) {
            cap *= 2;
            at = realloc(at, cap * sizeof *at);
            if (!at) {
                fputs("kelvin: out of memory\n", stderr);
                exit(1);
            }
        }
        kv_bytes b = kv_bytes_from(p, len);
        at[k++] = kv_string_from_bytes(&b);
        kv_bytes_free(&b);
        p += len;
        n -= len;
    }
    *out = at;
    *count = k;
}

void ucd_free_strings(kv_string *at, size_t n) {
    for (size_t i = 0; i < n; i++)
        kv_string_free(&at[i]);
    free(at);
}

/* ---------- case, category, name ---------- */

static kv_string map_string(const kv_string *s, uint32_t (*f)(uint32_t)) {
    kv_string r = kv_string_new();
    const uint8_t *p = kv_bytes_cstr(&s->b), *end = p + s->b.count;
    while (p < end)
        kv_string_append_cp(&r, f(kv_utf8_next(&p)));
    return r;
}

kv_string ucd_upper(const kv_string *s) { return map_string(s, ucd_to_upper); }
kv_string ucd_lower(const kv_string *s) { return map_string(s, ucd_to_lower); }
kv_string ucd_fold(const kv_string *s) { return map_string(s, ucd_to_fold); }

const uint8_t *ucd_category(uint32_t cp) { return (const uint8_t *)kv_ud_categories[kv_ud_cat(cp)]; }
uint8_t ucd_category_index(uint32_t cp) { return kv_ud_cat(cp); }
int ucd_combining(uint32_t cp) { return kv_ud_ccc(cp); }

kv_string ucd_name_of(uint32_t cp) {
    char buf[64];
    return kv_string_text(kv_ud_name(cp, buf, sizeof buf));
}

/* ---------- scripts and properties (#157) ---------- */

int ucd_script(uint32_t cp) { return kv_ud_script(cp); }

int ucd_script_id(const uint8_t *name) {
    for (size_t i = 0; i < kv_ud_script_count; i++)
        if (!strcmp((const char *)name, kv_ud_script_names[i][0]) || !strcmp((const char *)name, kv_ud_script_names[i][1]))
            return (int)i;
    return -1;
}

const uint8_t *ucd_script_name(int id) {
    return (const uint8_t *)(id >= 0 && (size_t)id < kv_ud_script_count ? kv_ud_script_names[id][0] : "Unknown");
}

bool ucd_scx_has(uint32_t cp, int id) {
    size_t lo = 0, hi = kv_ud_scx_range_count;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        const kv_ud_scx_range *r = &kv_ud_scx_ranges[mid];
        if (cp < r->lo) hi = mid;
        else if (cp > r->hi) lo = mid + 1;
        else {
            for (uint32_t k = 0; k < r->count; k++)
                if (kv_ud_scx_pool[r->offset + k] == id) return true;
            return false;
        }
    }
    return kv_ud_script(cp) == id;
}

int ucd_property_id(const uint8_t *name) {
    for (size_t i = 0; i < kv_ud_prop_count; i++)
        if (!strcmp((const char *)name, kv_ud_props[i].name) || (*kv_ud_props[i].alias && !strcmp((const char *)name, kv_ud_props[i].alias)))
            return (int)i;
    return -1;
}

bool ucd_has_property(uint32_t cp, int id) {
    if (id < 0 || (size_t)id >= kv_ud_prop_count) return false;
    const kv_ud_span *rs = kv_ud_prop_ranges + kv_ud_props[id].offset;
    size_t lo = 0, hi = kv_ud_props[id].count;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        if (cp < rs[mid].lo) hi = mid;
        else if (cp > rs[mid].hi) lo = mid + 1;
        else return true;
    }
    return false;
}

uint32_t ucd_category_mask(const uint8_t *name) {
    for (size_t i = 0; i < kv_ud_gc_name_count; i++)
        if (!strcmp((const char *)name, kv_ud_gc_names[i].name))
            return kv_ud_gc_names[i].mask;
    return 0;
}
