/* string.c - the text of values: x.cstr (#22), and x.dec, x.hex, x.oct
   and x.bin (#21)

   Every function writes into a buffer on the caller's stack, which
   kelvinc sizes for the longest text the value can have, and returns it
   as u8^. Nothing is allocated. */
#include "kelvin_prelude.h"

#include <complex.h>
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __SIZEOF_INT128__
typedef unsigned __int128 umax;
#else
typedef unsigned long long umax;
#endif

/* digits of v in base 2, 8, 10 or 16 into out (at least 132 bytes) */
static void digits(umax v, int base, bool upper, char *out) {
    const char *set = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    char buf[132];
    char *p = buf + sizeof buf;
    *--p = '\0';
    do {
        *--p = set[(int)(v % (unsigned)base)];
        v /= (unsigned)base;
    } while (v);
    strcpy(out, p);
}

/* ---------- x.cstr (#22) ---------- */

static uint8_t *put(uint8_t *buf, const char *text) {
    strcpy((char *)buf, text);
    return buf;
}

uint8_t *kv_cstr_bool(bool v, uint8_t *buf) { return put(buf, v ? "true" : "false"); }

uint8_t *kv_cstr_char(char v, uint8_t *buf) {
    buf[0] = (uint8_t)v;
    buf[1] = '\0';
    return buf;
}

uint8_t *kv_cstr_i64(long long v, uint8_t *buf) {
    snprintf((char *)buf, KV_CSTR_SCALAR, "%lld", v);
    return buf;
}

uint8_t *kv_cstr_u64(unsigned long long v, uint8_t *buf) {
    snprintf((char *)buf, KV_CSTR_SCALAR, "%llu", v);
    return buf;
}

/* as print shows it (#258): every digit, with a point, "1.0" and
   "0.10000000000000001" (#259), so that the text of an Array, a struct
   or an Optional pastes back into Kelvin as the value; a NaN has no
   meaningful sign and is "nan" */
uint8_t *kv_cstr_f32(float v, uint8_t *buf) {
    char t[96];
    snprintf((char *)buf, KV_CSTR_SCALAR, "%s", kv_f32_text(v, t));
    return buf;
}

uint8_t *kv_cstr_f64(double v, uint8_t *buf) {
    char t[96];
    snprintf((char *)buf, KV_CSTR_SCALAR, "%s", kv_f64_text(v, t));
    return buf;
}

uint8_t *kv_cstr_f80(long double v, uint8_t *buf) {
    char t[96];
    snprintf((char *)buf, KV_CSTR_SCALAR, "%s", kv_f80_text(v, t));
    return buf;
}

/* re+imi; buf already holds re */
static uint8_t *complex_text(uint8_t *buf, const uint8_t *im) {
    if (im[0] != '-')
        strcat((char *)buf, "+");
    strcat((char *)buf, (const char *)im);
    strcat((char *)buf, "i");
    return buf;
}

uint8_t *kv_cstr_cf(float _Complex v, uint8_t *buf) {
    uint8_t im[KV_CSTR_SCALAR];
    return complex_text(kv_cstr_f32(crealf(v), buf), kv_cstr_f32(cimagf(v), im));
}

uint8_t *kv_cstr_cd(double _Complex v, uint8_t *buf) {
    uint8_t im[KV_CSTR_SCALAR];
    return complex_text(kv_cstr_f64(creal(v), buf), kv_cstr_f64(cimag(v), im));
}

uint8_t *kv_cstr_cld(long double _Complex v, uint8_t *buf) {
    uint8_t im[KV_CSTR_SCALAR];
    return complex_text(kv_cstr_f80(creall(v), buf), kv_cstr_f80(cimagl(v), im));
}

/* a string is its own text; kv_cstr_cstr keeps a const string const */
uint8_t *kv_cstr_str(const char *v, uint8_t *buf) { return v ? (uint8_t *)v : put(buf, "nullptr"); } /* (#260) */

const uint8_t *kv_cstr_cstr(const char *v, uint8_t *buf) { return kv_cstr_str(v, buf); }

/* an address as 0x and its digits; a null pointer is nullptr, as Kelvin
   writes it (#260): 0x0 would read back as 0, an i64 */
uint8_t *kv_cstr_ptr(const volatile void *v, uint8_t *buf) {
    if (!v)
        return put(buf, "nullptr");
    char hex[132];
    digits((uintptr_t)v, 16, false, hex);
    strcpy((char *)buf, "0x");
    strcat((char *)buf, hex);
    return buf;
}

#ifdef __SIZEOF_INT128__
uint8_t *kv_cstr_u128(unsigned __int128 v, uint8_t *buf) {
    char text[132];
    digits(v, 10, false, text);
    return put(buf, text);
}

uint8_t *kv_cstr_i128(__int128 v, uint8_t *buf) {
    char text[132];
    /* negate as unsigned so that the minimum value works too */
    digits(v < 0 ? (umax)0 - (umax)v : (umax)v, 10, false, text);
    strcpy((char *)buf, v < 0 ? "-" : "");
    strcat((char *)buf, text);
    return buf;
}
#endif

/* ---------- the derived text of structs ---------- */

uint8_t *kv_cstr_end(uint8_t *s) { return s + strlen((char *)s); }

uint8_t *kv_cstr_put(uint8_t *p, const char *text) {
    size_t n = strlen(text);
    memcpy(p, text, n + 1);
    return p + n;
}

/* the text in s, up to its NUL or `limit` bytes; more than KV_CSTR_STR
   bytes are cut and end in "..." */
static uint8_t *put_chars(uint8_t *p, const char *s, size_t limit) {
    size_t n = 0;
    while (n < limit && n <= KV_CSTR_STR && s[n])
        n++;
    if (n > KV_CSTR_STR) {
        memcpy(p, s, KV_CSTR_STR - 3);
        return kv_cstr_put(p + KV_CSTR_STR - 3, "...");
    }
    memcpy(p, s, n);
    p[n] = '\0';
    return p + n;
}

/* ---------- text inside a value, quoted (#123) ---------- */

/* the escape of byte c in quoted text, into e; its length */
static size_t quote_escape(uint8_t c, bool bytes, char e[8]) {
    switch (c) {
    case '"': return (size_t)snprintf(e, 8, "\\\"");
    case '\\': return (size_t)snprintf(e, 8, "\\\\");
    case '\n': return (size_t)snprintf(e, 8, "\\n");
    case '\r': return (size_t)snprintf(e, 8, "\\r");
    case '\t': return (size_t)snprintf(e, 8, "\\t");
    default: break;
    }
    if (c < 0x20 || c == 0x7F)
        return (size_t)snprintf(e, 8, bytes ? "\\x%02x" : "\\u%04x", c);
    if (bytes && c >= 0x80)
        return (size_t)snprintf(e, 8, "\\x%02x", c);
    e[0] = (char)c;
    e[1] = 0;
    return 1;
}

/* "at", escaped, in at most room bytes and a NUL; cut with ..." where the
   whole does not fit, never inside a codepoint of text */
static uint8_t *quoted_into(const uint8_t *at, size_t n, size_t room, bool bytes, uint8_t *p) {
    char e[8];
    size_t whole = 2;
    for (size_t i = 0; i < n; i++)
        whole += quote_escape(at[i], bytes, e);
    size_t used = 0;
    p[used++] = '"';
    for (size_t i = 0; i < n; i++) {
        size_t k = quote_escape(at[i], bytes, e);
        if (whole > room) {
            bool starts = bytes || (at[i] & 0xC0) != 0x80;
            if (starts && used + k + 4 > room)
                break;
        }
        memcpy(p + used, e, k);
        used += k;
        if (whole > room && i + 1 < n && used + 4 > room)
            break;
    }
    if (whole > room) {
        while (!bytes && used > 1 && (p[used - 1] & 0xC0) == 0x80) /* not inside a codepoint */
            used--;
        if (!bytes && used > 1 && p[used - 1] >= 0xC0)
            used--;
        memcpy(p + used, "...", 3);
        used += 3;
    }
    p[used++] = '"';
    p[used] = 0;
    return p + used;
}

uint8_t *kv_cstr_quoted_string(kv_string s, uint8_t *p) {
    return quoted_into(s.b.at ? s.b.at : (const uint8_t *)"", s.b.count, KV_CSTR_SCALAR - 1, false, p);
}

uint8_t *kv_cstr_quoted_bytes(kv_bytes b, uint8_t *p) {
    return quoted_into(b.at ? b.at : (const uint8_t *)"", b.count, KV_CSTR_SCALAR - 1, true, p);
}

uint8_t *kv_cstr_quoted_str(const char *s, uint8_t *p) {
    if (!s)
        return kv_cstr_put(p, "nullptr"); /* as Kelvin writes it (#259) */
    return quoted_into((const uint8_t *)s, strlen(s), KV_CSTR_STR, false, p);
}

/* text of a type only C sees inside a value (#259), as xmlChar^: quoted,
   as a cstr's, so that it pastes back */
uint8_t *kv_cstr_quoted_text(uint8_t *p, const void *s) { return kv_cstr_quoted_str((const char *)s, p); }

uint8_t *kv_cstr_put_str(uint8_t *p, const char *s) { return s ? put_chars(p, s, SIZE_MAX) : kv_cstr_put(p, "nullptr"); } /* (#260) */

uint8_t *kv_cstr_put_text(uint8_t *p, const void *s) { return kv_cstr_put_str(p, (const char *)s); }

uint8_t *kv_cstr_put_address(uint8_t *p, const volatile void *v) { return kv_cstr_end(kv_cstr_ptr(v, p)); }

/* ---------- properties: .dec, .hex, .oct, .bin (#21) ---------- */

/* sign (signed types always have one), prefix, digits */
static uint8_t *number_text(bool is_signed, bool neg, umax mag, int base, uint8_t *buf) {
    const char *prefix = base == 16 ? "0x" : base == 8 ? "0o" : base == 2 ? "0b" : "";
    char num[132], text[140] = "";
    digits(mag, base, false, num);
    strcat(text, is_signed ? (neg ? "-" : "+") : "");
    strcat(text, prefix);
    strcat(text, num);
    strcpy((char *)buf, text); /* kelvinc sizes buf for the longest text */
    return buf;
}

/* the magnitude of v without overflowing on the minimum value */
static umax magnitude(long long v) { return v < 0 ? (umax)(-(v + 1)) + 1 : (umax)v; }

#define KV_INT_PROPERTIES(name, base) \
    uint8_t *kv_##name##_signed(long long v, uint8_t *buf) { \
        return number_text(true, v < 0, magnitude(v), base, buf); \
    } \
    uint8_t *kv_##name##_unsigned(unsigned long long v, uint8_t *buf) { \
        return number_text(false, false, v, base, buf); \
    } \
    uint8_t *kv_##name##_char(char v, uint8_t *buf) { /* C's char may be either */ \
        return CHAR_MIN < 0 ? kv_##name##_signed(v, buf) : kv_##name##_unsigned((unsigned char)v, buf); \
    }
KV_INT_PROPERTIES(dec, 10)
KV_INT_PROPERTIES(hex, 16)
KV_INT_PROPERTIES(oct, 8)
KV_INT_PROPERTIES(bin, 2)

#ifdef __SIZEOF_INT128__
#define KV_INT128_PROPERTIES(name, base) \
    uint8_t *kv_##name##_i128(__int128 v, uint8_t *buf) { \
        return number_text(true, v < 0, v < 0 ? (umax)0 - (umax)v : (umax)v, base, buf); \
    } \
    uint8_t *kv_##name##_u128(unsigned __int128 v, uint8_t *buf) { \
        return number_text(false, false, v, base, buf); \
    }
KV_INT128_PROPERTIES(dec, 10)
KV_INT128_PROPERTIES(hex, 16)
KV_INT128_PROPERTIES(oct, 8)
KV_INT128_PROPERTIES(bin, 2)
#endif

/* floats: always signed; a NaN has no meaningful sign and is "nan" */
static uint8_t *float_text(double v, const char *format, uint8_t *buf) {
    char text[64] = "nan";
    if (!isnan(v))
        snprintf(text, sizeof text, format, v);
    strcpy((char *)buf, text); /* kelvinc sizes buf for the longest text */
    return buf;
}

uint8_t *kv_dec_f32(float v, uint8_t *buf) { return float_text(v, "%+.9g", buf); }
uint8_t *kv_dec_f64(double v, uint8_t *buf) { return float_text(v, "%+.17g", buf); }
uint8_t *kv_hex_f32(float v, uint8_t *buf) { return float_text(v, "%+a", buf); }
uint8_t *kv_hex_f64(double v, uint8_t *buf) { return float_text(v, "%+a", buf); }

/* ---------- p.hex (#37) ---------- */

uint8_t *kv_hex_addr(uintptr_t v, uint8_t *buf) {
    char digits_buf[132];
    digits(v, 16, false, digits_buf);
    size_t width = 2 * sizeof v, n = strlen(digits_buf);
    char *out = (char *)buf;
    out[0] = '0';
    out[1] = 'x';
    memset(out + 2, '0', width - n);
    strcpy(out + 2 + width - n, digits_buf);
    return buf;
}

uint8_t *kv_hex_ptr(const volatile void *p, uint8_t *buf) { return kv_hex_addr((uintptr_t)p, buf); }

/* ---------- numbers from text (#36) ---------- */

/* The text after leading spaces and a sign, which *neg tells, past
   Kelvin's own 0o and 0b in base 8 and 2 (strtoull skips 0x in base 16
   itself); NULL when no digit can follow */
static const char *digits_of(const void *text, long long base, bool *neg) {
    const char *s = text;
    *neg = false;
    if (!s || base < 2 || base > 36)
        return NULL;
    while (isspace((unsigned char)*s))
        s++;
    if (*s == '+' || *s == '-')
        *neg = *s++ == '-';
    if (s[0] == '0' && ((base == 8 && (s[1] == 'o' || s[1] == 'O')) || (base == 2 && (s[1] == 'b' || s[1] == 'B'))))
        s += 2;
    return isalnum((unsigned char)*s) ? s : NULL; /* no second sign or space, as in strtol */
}

/* The magnitude of the integer at the start of text, as strtoull reads
   it; *over tells that it did not fit */
static unsigned long long magnitude_of(const void *text, long long base, bool *neg, bool *over) {
    const char *s = digits_of(text, base, neg);
    *over = false;
    if (!s)
        return 0;
    int saved = errno;
    errno = 0;
    char *end;
    unsigned long long m = strtoull(s, &end, (int)base);
    *over = errno == ERANGE;
    errno = saved;
    return end == s ? 0 : m;
}

int64_t kv_text_int(const void *text, long long base, int64_t min, int64_t max) {
    bool neg, over;
    unsigned long long m = magnitude_of(text, base, &neg, &over);
    unsigned long long lowest = (unsigned long long)-(min + 1) + 1; /* -min, without overflow */
    if (neg && (over || m > lowest)) {
        errno = ERANGE;
        return min;
    }
    if (neg)
        return m == lowest ? min : -(int64_t)m;
    if (over || m > (unsigned long long)max) {
        errno = ERANGE;
        return max;
    }
    return (int64_t)m;
}

uint64_t kv_text_uint(const void *text, long long base, uint64_t max) {
    bool neg, over;
    unsigned long long m = magnitude_of(text, base, &neg, &over);
    if (neg && m) { /* below 0, the lowest an unsigned type has */
        errno = ERANGE;
        return 0;
    }
    if (over || m > max) {
        errno = ERANGE;
        return max;
    }
    return m;
}

double kv_text_f64(const void *text) { return text ? strtod(text, NULL) : 0; }
float kv_text_f32(const void *text) { return text ? strtof(text, NULL) : 0; }

#ifdef __SIZEOF_INT128__
static int digit_value(char c) {
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'z')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'Z')
        return c - 'A' + 10;
    return 99;
}

/* The same for i128 and u128, which strtoull is too narrow for: digits
   are read one by one, with 0x skipped in base 16 as strtoull skips it */
static unsigned __int128 magnitude128(const void *text, long long base, bool *neg, bool *over) {
    const char *s = digits_of(text, base, neg);
    *over = false;
    if (!s)
        return 0;
    if (base == 16 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X') && digit_value(s[2]) < 16)
        s += 2;
    unsigned __int128 m = 0, all = ~(unsigned __int128)0;
    for (int d; (d = digit_value(*s)) < base; s++) {
        if (m > (all - (unsigned)d) / (unsigned)base)
            *over = true;
        else
            m = m * (unsigned)base + (unsigned)d;
    }
    return m;
}

__int128 kv_text_i128(const void *text, long long base) {
    bool neg, over;
    unsigned __int128 m = magnitude128(text, base, &neg, &over);
    unsigned __int128 lowest = (unsigned __int128)1 << 127; /* -min */
    __int128 max = (__int128)(lowest - 1), min = -max - 1;
    if (neg && (over || m > lowest)) {
        errno = ERANGE;
        return min;
    }
    if (neg)
        return m == lowest ? min : -(__int128)m;
    if (over || m > (unsigned __int128)max) {
        errno = ERANGE;
        return max;
    }
    return (__int128)m;
}

unsigned __int128 kv_text_u128(const void *text, long long base) {
    bool neg, over;
    unsigned __int128 m = magnitude128(text, base, &neg, &over);
    if (neg && m) {
        errno = ERANGE;
        return 0;
    }
    if (over) {
        errno = ERANGE;
        return ~(unsigned __int128)0;
    }
    return m;
}
#endif

/* ---------- values of types kelvinc cannot see ---------- */

uint8_t *kv_cstr_kind(const void *p, int kind, size_t size, uint8_t *buf) {
    switch (kind) {
    case KV_K_BOOL: return kv_cstr_bool(*(const bool *)p, buf);
    case KV_K_CHAR: return kv_cstr_char(*(const char *)p, buf);
    case KV_K_SCHAR: return kv_cstr_i64(*(const signed char *)p, buf);
    case KV_K_UCHAR: return kv_cstr_u64(*(const unsigned char *)p, buf);
    case KV_K_SHORT: return kv_cstr_i64(*(const short *)p, buf);
    case KV_K_USHORT: return kv_cstr_u64(*(const unsigned short *)p, buf);
    case KV_K_INT: return kv_cstr_i64(*(const int *)p, buf);
    case KV_K_UINT: return kv_cstr_u64(*(const unsigned *)p, buf);
    case KV_K_LONG: return kv_cstr_i64(*(const long *)p, buf);
    case KV_K_ULONG: return kv_cstr_u64(*(const unsigned long *)p, buf);
    case KV_K_LLONG: return kv_cstr_i64(*(const long long *)p, buf);
    case KV_K_ULLONG: return kv_cstr_u64(*(const unsigned long long *)p, buf);
#ifdef __SIZEOF_INT128__
    case KV_K_I128: return kv_cstr_i128(*(const __int128 *)p, buf);
    case KV_K_U128: return kv_cstr_u128(*(const unsigned __int128 *)p, buf);
#endif
    case KV_K_FLOAT: return kv_cstr_f32(*(const float *)p, buf);
    case KV_K_DOUBLE: return kv_cstr_f64(*(const double *)p, buf);
    case KV_K_LDOUBLE: return kv_cstr_f80(*(const long double *)p, buf);
    /* text inside a value, quoted as a cstr's (#259) */
    case KV_K_STR: kv_cstr_quoted_str(*(const char *const *)p, buf); return buf;
    case KV_K_CHARS: {
        size_t n = 0; /* up to a NUL, or the end of the array */
        while (n < size && ((const char *)p)[n])
            n++;
        quoted_into((const uint8_t *)p, n, KV_CSTR_STR, false, buf);
        return buf;
    }
    case KV_K_PTR: return kv_cstr_ptr(*(const void *const *)p, buf);
    case KV_K_CF: return kv_cstr_cf(*(const float _Complex *)p, buf);
    case KV_K_CD: return kv_cstr_cd(*(const double _Complex *)p, buf);
    case KV_K_CLD: return kv_cstr_cld(*(const long double _Complex *)p, buf);
    default: return put(buf, "{...}");
    }
}

/* String(n) of a number or a bool (#158): its text, as print shows it */
kv_string kv_string_bool(bool v) {
    uint8_t buf[KV_CSTR_SCALAR];
    return kv_string_text(kv_cstr_bool(v, buf));
}
kv_string kv_string_i64(long long v) {
    uint8_t buf[KV_CSTR_SCALAR];
    return kv_string_text(kv_cstr_i64(v, buf));
}
kv_string kv_string_u64(unsigned long long v) {
    uint8_t buf[KV_CSTR_SCALAR];
    return kv_string_text(kv_cstr_u64(v, buf));
}
kv_string kv_string_f32(float v) {
    uint8_t buf[KV_CSTR_SCALAR];
    return kv_string_text(kv_cstr_f32(v, buf));
}
kv_string kv_string_f64(double v) {
    uint8_t buf[KV_CSTR_SCALAR];
    return kv_string_text(kv_cstr_f64(v, buf));
}

/* s.escape() (#164): the text with each codepoint beyond ASCII as \u{...},
   and a backslash as \\, so that unescape reads it back; rx_escape does the
   same for what a RegExp matches */
static void escape_cp(kv_string *out, uint32_t cp) {
    char buf[16];
    snprintf(buf, sizeof buf, "\\u{%X}", (unsigned)cp);
    kv_string_append_text(out, buf);
}

kv_string kv_string_escape(const kv_string *s) {
    kv_string out = kv_string_new();
    const uint8_t *p = s->b.at ? s->b.at : (const uint8_t *)"";
    while (*p) {
        uint32_t cp = kv_utf8_next(&p);
        if (cp == '\\')
            kv_string_append_text(&out, "\\\\");
        else if (cp < 0x80)
            kv_string_append_cp(&out, cp);
        else
            escape_cp(&out, cp);
    }
    return out;
}

static int hex_value(uint8_t c) {
    return c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
}

/* n hex digits at p, or -1 */
static int64_t hex_run(const uint8_t *p, int n) {
    int64_t v = 0;
    for (int i = 0; i < n; i++) {
        int h = hex_value(p[i]);
        if (h < 0)
            return -1;
        v = v * 16 + h;
    }
    return v;
}

/* s.unescape() (#164): \u{...}, \uHHHH (a surrogate pair joined), \xHH, \n,
   \r, \t, \0, \\, \" and \' read back; an escape that is none of these,
   or a codepoint that is not one, stays as written */
kv_string kv_string_unescape(const kv_string *s) {
    kv_string out = kv_string_new();
    const uint8_t *p = s->b.at ? s->b.at : (const uint8_t *)"";
    while (*p) {
        if (*p != '\\' || !p[1]) {
            uint32_t cp = kv_utf8_next(&p);
            kv_string_append_cp(&out, cp);
            continue;
        }
        uint8_t e = p[1];
        int64_t cp = -1;
        const uint8_t *next = p + 2;
        if (e == 'u' && p[2] == '{') {
            const uint8_t *q = p + 3;
            int64_t v = 0;
            int n = 0;
            while (hex_value(*q) >= 0 && n < 8) {
                v = v * 16 + hex_value(*q++);
                n++;
            }
            if (n && *q == '}' && v <= 0x10FFFF && !(v >= 0xD800 && v <= 0xDFFF)) {
                cp = v;
                next = q + 1;
            }
        } else if (e == 'u') {
            int64_t v = hex_run(p + 2, 4);
            if (v >= 0xD800 && v <= 0xDBFF && p[6] == '\\' && p[7] == 'u') {
                int64_t lo = hex_run(p + 8, 4);
                if (lo >= 0xDC00 && lo <= 0xDFFF) {
                    cp = 0x10000 + ((v - 0xD800) << 10) + (lo - 0xDC00);
                    next = p + 12;
                }
            } else if (v >= 0 && !(v >= 0xD800 && v <= 0xDFFF)) {
                cp = v;
                next = p + 6;
            }
        } else if (e == 'x') {
            cp = hex_run(p + 2, 2);
            next = p + 4;
        } else if (e == 'n') {
            cp = '\n';
        } else if (e == 'r') {
            cp = '\r';
        } else if (e == 't') {
            cp = '\t';
        } else if (e == '0') {
            cp = 0;
        } else if (e == '\\' || e == '"' || e == '\'') {
            cp = e;
        }
        if (cp < 0) { /* not an escape: the backslash as it is */
            kv_string_append_cp(&out, '\\');
            p++;
            continue;
        }
        kv_string_append_cp(&out, (uint32_t)cp);
        p = next;
    }
    return out;
}

/* s.find(text), s.has(text), s.starts(text), s.ends(text) (#177): by the
   bytes, the index found as a codepoint count; s.trim(): without the
   blanks at either end, JS's \s, a new String */
static int64_t find_bytes(const kv_string *s, const uint8_t *p, size_t n) {
    if (n > s->b.count)
        return -1;
    const uint8_t *at = s->b.at ? s->b.at : (const uint8_t *)"";
    for (size_t i = 0; i + n <= s->b.count; i++)
        if (!memcmp(at + i, p, n)) {
            int64_t k = 0;
            for (size_t j = 0; j < i; j++)
                if ((at[j] & 0xC0) != 0x80)
                    k++;
            return k;
        }
    return -1;
}

int64_t kv_string_find_text(const kv_string *s, const void *t) { return find_bytes(s, t, strlen(t)); }
int64_t kv_string_find_ref(const kv_string *s, const kv_string *t) { return find_bytes(s, t->b.at ? t->b.at : (const uint8_t *)"", t->b.count); }
bool kv_string_has_text(const kv_string *s, const void *t) { return kv_string_find_text(s, t) >= 0; }
bool kv_string_has_ref(const kv_string *s, const kv_string *t) { return kv_string_find_ref(s, t) >= 0; }

static bool starts_bytes(const kv_string *s, const uint8_t *p, size_t n) {
    return n <= s->b.count && (n == 0 || !memcmp(s->b.at, p, n));
}
static bool ends_bytes(const kv_string *s, const uint8_t *p, size_t n) {
    return n <= s->b.count && (n == 0 || !memcmp(s->b.at + s->b.count - n, p, n));
}
bool kv_string_starts_text(const kv_string *s, const void *t) { return starts_bytes(s, t, strlen(t)); }
bool kv_string_starts_ref(const kv_string *s, const kv_string *t) { return starts_bytes(s, t->b.at ? t->b.at : (const uint8_t *)"", t->b.count); }
bool kv_string_ends_text(const kv_string *s, const void *t) { return ends_bytes(s, t, strlen(t)); }
bool kv_string_ends_ref(const kv_string *s, const kv_string *t) { return ends_bytes(s, t->b.at ? t->b.at : (const uint8_t *)"", t->b.count); }

static bool is_blank_cp(uint32_t c) {
    return c == 9 || c == 10 || c == 11 || c == 12 || c == 13 || c == ' ' || c == 0xA0 || c == 0x1680 ||
           (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000 ||
           c == 0xFEFF;
}

kv_string kv_string_trim(const kv_string *s) {
    const uint8_t *p = s->b.at ? s->b.at : (const uint8_t *)"", *end = p + s->b.count;
    const uint8_t *lo = p, *hi = end;
    while (lo < hi) {
        const uint8_t *q = lo;
        if (!is_blank_cp(kv_utf8_next(&q)))
            break;
        lo = q;
    }
    while (hi > lo) {
        const uint8_t *q = hi - 1;
        while (q > lo && (*q & 0xC0) == 0x80)
            q--;
        const uint8_t *r = q;
        if (!is_blank_cp(kv_utf8_next(&r)))
            break;
        hi = q;
    }
    kv_string out = kv_string_new();
    if (hi > lo) {
        kv_bytes_append(&out.b, lo, (size_t)(hi - lo));
        for (const uint8_t *q = lo; q < hi; q++)
            if ((*q & 0xC0) != 0x80)
                out.count++;
    }
    return out;
}
