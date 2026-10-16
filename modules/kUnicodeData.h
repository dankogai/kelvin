/* kUnicodeData.h - the declarations of libkUnicodeData (#156): the Unicode
   Character Database as tables, runtime/unicode_tables.c and
   unicode_names.c, made by tools/gen_unicode.py, and what is done with
   them, runtime/unicode_data.c: normalization, grapheme clusters, case
   mappings, categories and names. #import <UnicodeData> brings in
   modules/UnicodeData.kh, which declares the Kelvin side, and links it. */
#ifndef KELVIN_KUNICODEDATA_H
#define KELVIN_KUNICODEDATA_H

#include "kelvin_prelude.h"

extern const char *const kv_ud_version;   /* "18.0.0" */

/* the properties of a codepoint, each by a two-level table */
uint8_t kv_ud_cat(uint32_t cp);  /* the general category, an index into kv_ud_categories */
uint8_t kv_ud_ccc(uint32_t cp);  /* the canonical combining class */
uint8_t kv_ud_gcb(uint32_t cp);  /* the grapheme cluster break property, an index into kv_ud_gcb_names */
uint8_t kv_ud_incb(uint32_t cp); /* the Indic conjunct break: 0 none, 1 consonant, 2 extend, 3 linker */
extern const char *const kv_ud_categories[30];
extern const char *const kv_ud_gcb_names[15];
/* scripts, script extensions and the binary properties (#157), for \p{...} */
typedef struct { uint32_t lo, hi; } kv_ud_span;
typedef struct { uint32_t lo, hi, offset, count; } kv_ud_scx_range; /* the set is kv_ud_scx_pool[offset..] */
typedef struct { const char *name, *alias; uint32_t offset, count; } kv_ud_prop; /* kv_ud_prop_ranges[offset..] */
typedef struct { const char *name; uint32_t mask; } kv_ud_gc_name; /* a bit per index of kv_ud_categories */
uint8_t kv_ud_script(uint32_t cp); /* an index into kv_ud_script_names, 0 Unknown */
extern const char *const kv_ud_script_names[][2]; /* the long name and the short one */
extern const size_t kv_ud_script_count;
extern const uint8_t kv_ud_scx_pool[];
extern const kv_ud_scx_range kv_ud_scx_ranges[];
extern const size_t kv_ud_scx_range_count;
extern const kv_ud_span kv_ud_prop_ranges[];
extern const kv_ud_prop kv_ud_props[];
extern const size_t kv_ud_prop_count;
extern const kv_ud_gc_name kv_ud_gc_names[];
extern const size_t kv_ud_gc_name_count;
enum { KV_GCB_OTHER, KV_GCB_CR, KV_GCB_LF, KV_GCB_CONTROL, KV_GCB_EXTEND, KV_GCB_ZWJ, KV_GCB_RI, KV_GCB_PREPEND,
       KV_GCB_SPACINGMARK, KV_GCB_L, KV_GCB_V, KV_GCB_T, KV_GCB_LV, KV_GCB_LVT, KV_GCB_PICTOGRAPHIC };

/* decompositions, compositions and case mappings, sorted for a binary search */
typedef struct { uint32_t cp, offset; uint8_t len, compat; } kv_ud_decomp;
typedef struct { uint32_t first, second, composed; } kv_ud_pair;
typedef struct { uint32_t from, to; } kv_ud_map;
typedef struct { uint32_t cp, offset; } kv_ud_name_entry;
typedef struct { uint32_t lo, hi; const char *kind; } kv_ud_range;
extern const uint32_t kv_ud_decomp_pool[];
extern const kv_ud_decomp kv_ud_decomps[];
extern const size_t kv_ud_decomp_count;
extern const kv_ud_pair kv_ud_pairs[];
extern const size_t kv_ud_pair_count;
extern const kv_ud_map kv_ud_upper[], kv_ud_lower[], kv_ud_title[], kv_ud_fold[];
extern const size_t kv_ud_upper_count, kv_ud_lower_count, kv_ud_title_count, kv_ud_fold_count;

/* the name of a codepoint, from the table or by rule, into buf where by rule; "" where none */
const char *kv_ud_name(uint32_t cp, char *buf, size_t max);

/* ---------- what a program calls, on a String and a uchr ---------- */
enum { KV_UD_NFC, KV_UD_NFD, KV_UD_NFKC, KV_UD_NFKD };
kv_string ucd_normalize(const kv_string *s, int form);
/* the grapheme clusters of s (UAX #29), as Strings in a malloc'd array, freed by ucd_free_strings */
void ucd_graphemes(const kv_string *s, kv_string **out, size_t *count);
void ucd_free_strings(kv_string *at, size_t n);
/* the bytes of the first grapheme cluster of the n bytes at p; 0 where n is 0 */
size_t ucd_grapheme_len(const uint8_t *p, size_t n);
/* simple case mappings, one codepoint to one; fold is the C + S case folding */
kv_string ucd_upper(const kv_string *s);
kv_string ucd_lower(const kv_string *s);
kv_string ucd_fold(const kv_string *s);
uint32_t ucd_to_upper(uint32_t cp);
uint32_t ucd_to_lower(uint32_t cp);
uint32_t ucd_to_fold(uint32_t cp);
/* of a codepoint: its category as text, "Lu"; its name as a String; its combining class */
const uint8_t *ucd_category(uint32_t cp);
uint8_t ucd_category_index(uint32_t cp); /* kv_ud_cat, by a name a Kelvin file may declare */
/* the script, the script extensions and the binary properties (#157): ids
   by name, -1 where there is none, long or short names as Unicode spells them */
int ucd_script(uint32_t cp);
int ucd_script_id(const uint8_t *name);
const uint8_t *ucd_script_name(int id);
bool ucd_scx_has(uint32_t cp, int id);
int ucd_property_id(const uint8_t *name);
bool ucd_has_property(uint32_t cp, int id);
uint32_t ucd_category_mask(const uint8_t *name); /* the categories a name covers, 0 where there is none */
kv_string ucd_name_of(uint32_t cp);
int ucd_combining(uint32_t cp);
/* the decomposition of a codepoint, canonical or with compatibility ones, as a String; "" where none */
kv_string ucd_decomposition(uint32_t cp, bool compat);

#endif
