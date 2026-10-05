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

/* lossless; a NaN has no meaningful sign and is "nan" */
uint8_t *kv_cstr_f32(float v, uint8_t *buf) {
    if (isnan(v))
        return put(buf, "nan");
    snprintf((char *)buf, KV_CSTR_SCALAR, "%.9g", (double)v);
    return buf;
}

uint8_t *kv_cstr_f64(double v, uint8_t *buf) {
    if (isnan(v))
        return put(buf, "nan");
    snprintf((char *)buf, KV_CSTR_SCALAR, "%.17g", v);
    return buf;
}

uint8_t *kv_cstr_f80(long double v, uint8_t *buf) {
    if (isnan(v))
        return put(buf, "nan");
    snprintf((char *)buf, KV_CSTR_SCALAR, "%.21Lg", v);
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
uint8_t *kv_cstr_str(const char *v, uint8_t *buf) { return v ? (uint8_t *)v : put(buf, "(null)"); }

const uint8_t *kv_cstr_cstr(const char *v, uint8_t *buf) { return kv_cstr_str(v, buf); }

uint8_t *kv_cstr_ptr(const volatile void *v, uint8_t *buf) {
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

uint8_t *kv_cstr_put_str(uint8_t *p, const char *s) { return s ? put_chars(p, s, SIZE_MAX) : kv_cstr_put(p, "(null)"); }

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
    case KV_K_STR: kv_cstr_put_str(buf, *(const char *const *)p); return buf;
    case KV_K_CHARS: put_chars(buf, (const char *)p, size); return buf;
    case KV_K_PTR: return kv_cstr_ptr(*(const void *const *)p, buf);
    case KV_K_CF: return kv_cstr_cf(*(const float _Complex *)p, buf);
    case KV_K_CD: return kv_cstr_cd(*(const double _Complex *)p, buf);
    case KV_K_CLD: return kv_cstr_cld(*(const long double _Complex *)p, buf);
    default: return put(buf, "{...}");
    }
}
