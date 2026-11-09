/* kRegExp.h - the engine of the prelude's RegExp (#157, #504): JS's regular
   expressions over Kelvin's Strings, in runtime/regexp.c, which libkelvin
   holds with UnicodeData under it; its functions are kv_rx_ (#504). A pattern compiles to a program held in a Bytes,
   so that a RegExp is an owner as any Bytes is; a search gives the byte
   offsets of the match and its groups. modules/RegExp.k wraps it. */
#ifndef KREGEXP_H
#define KREGEXP_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "kelvin_prelude.h"

/* the program of a pattern with flags of "dgimsuy", JS's; a pattern that is
   not one ends the program, naming what is wrong and where */
kv_bytes kv_rx_compile(const uint8_t *pattern, const uint8_t *flags);
/* NULL where the pattern with the flags is one, else what is wrong, with *at
   where in the pattern; nothing ends: kelvinc checks a $/.../ literal (#163) */
const char *rx_check(const char *pattern, const char *flags, size_t *at);
int64_t kv_rx_groups(const kv_bytes *prog);                           /* the capturing groups, not counting the whole */
const uint8_t *kv_rx_group_name(const kv_bytes *prog, int64_t i);      /* "" where group i has no name */
int64_t kv_rx_group_named(const kv_bytes *prog, const uint8_t *name);  /* -1 where there is none */
bool kv_rx_flag(const kv_bytes *prog, uint8_t flag);                   /* 'g', 'i', 'm', 's', 'y', 'd', 'u' */

/* a match at or after byte offset from (at it alone when sticky): caps gets
   2 * (groups + 1) byte offsets, start and end of the whole and of each
   group, -1 where a group took no part */
bool kv_rx_search(const kv_bytes *prog, const kv_string *s, int64_t from, bool sticky, int64_t *caps);

/* the replacement of one match, JS's: $$, $&, $1..$99, $<name>, $` and $',
   appended to out */
void kv_rx_expand(const kv_bytes *prog, const kv_string *s, const int64_t *caps, const uint8_t *with, kv_string *out);

/* s.escape(&re) (#164): each codepoint of each match as \u{...}, a backslash as \\ */
kv_string kv_rx_escape(const kv_bytes *prog, const kv_string *s);
/* s.unescape(&re) (#165): the escapes read back in what the pattern matches alone */
kv_string kv_rx_unescape(const kv_bytes *prog, const kv_string *s);
/* a Bytes (#168), matched byte by byte, each byte the codepoint of its value */
bool kv_rx_search_bytes(const kv_bytes *prog, const kv_bytes *b, int64_t from, bool sticky, int64_t *caps);
kv_string kv_rx_escape_bytes(const kv_bytes *prog, const kv_bytes *b);    /* b.escape(&re): matched bytes as \xHH */
kv_bytes kv_rx_unescape_bytes(const kv_bytes *prog, const uint8_t *text, size_t len); /* Bytes.unescape(text, &re) */
kv_bytes kv_rx_bytes_slice(const kv_bytes *b, int64_t lo, int64_t hi);              /* bytes lo..<hi, a new Bytes (#169) */
/* the replacement of one match in a Bytes (#170), JS's patterns over bytes, appended to out */
void kv_rx_expand_bytes(const kv_bytes *prog, const kv_bytes *b, const int64_t *caps, const uint8_t *with, size_t len,
                     kv_bytes *out);

/* bytes and codepoints of a String */
kv_string kv_rx_slice(const kv_string *s, int64_t lo, int64_t hi);  /* bytes lo..<hi, a new String */
int64_t kv_rx_cp_index(const kv_string *s, int64_t byte);            /* the codepoints before byte offset byte */
int64_t kv_rx_byte_index(const kv_string *s, int64_t cp);            /* the byte offset of codepoint cp, or the end */
int64_t kv_rx_next(const kv_string *s, int64_t byte);                /* the byte after the codepoint at byte */

#endif
