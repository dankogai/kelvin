/* string.c - String, toString() and fmt() for the built-in types

   fmt() never hands the caller's format to snprintf. It parses the one
   conversion into bounded fields, formats integers itself (so every
   width and flag is defined, for every integer size), and builds a
   fresh, minimal format for floating-point conversions. */
#include "kelvin_prelude.h"

#include <complex.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#ifdef __SIZEOF_INT128__
typedef unsigned __int128 umax;
#else
typedef unsigned long long umax;
#endif

void kv_string_append(kv_String *s, const char *text) {
    size_t used = strlen((char *)s->bytes);
    size_t room = KV_STRING_SIZE - 1 - used;
    size_t n = strlen(text);
    if (n > room)
        n = room;
    memcpy(s->bytes + used, text, n);
    s->bytes[used + n] = '\0';
}

static kv_String from_text(const char *text) {
    kv_String s = {{0}};
    kv_string_append(&s, text);
    return s;
}

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

/* ---------- toString ---------- */

kv_String kv_toString_bool(bool v) { return from_text(v ? "true" : "false"); }

kv_String kv_toString_char(char v) {
    kv_String s = {{0}};
    s.bytes[0] = (unsigned char)v;
    return s;
}

kv_String kv_toString_i64(long long v) {
    kv_String s = {{0}};
    snprintf((char *)s.bytes, sizeof s.bytes, "%lld", v);
    return s;
}

kv_String kv_toString_u64(unsigned long long v) {
    kv_String s = {{0}};
    snprintf((char *)s.bytes, sizeof s.bytes, "%llu", v);
    return s;
}

kv_String kv_toString_f32(float v) {
    kv_String s = {{0}};
    snprintf((char *)s.bytes, sizeof s.bytes, "%.9g", (double)v);
    return s;
}

kv_String kv_toString_f64(double v) {
    kv_String s = {{0}};
    snprintf((char *)s.bytes, sizeof s.bytes, "%.17g", v);
    return s;
}

kv_String kv_toString_f80(long double v) {
    kv_String s = {{0}};
    snprintf((char *)s.bytes, sizeof s.bytes, "%.21Lg", v);
    return s;
}

kv_String kv_toString_str(const char *v) { return from_text(v ? v : "(null)"); }

kv_String kv_toString_ptr(const void *v) {
    kv_String s = {{0}};
    snprintf((char *)s.bytes, sizeof s.bytes, "%p", v);
    return s;
}

kv_String kv_toString_String(kv_String v) { return v; }

/* complex numbers print as re+imi, each part lossless */
static kv_String complex_text(kv_String re, kv_String im) {
    kv_String s = re;
    if (im.bytes[0] != '-')
        kv_string_append(&s, "+");
    kv_string_append(&s, (const char *)im.bytes);
    kv_string_append(&s, "i");
    return s;
}

kv_String kv_toString_cf(float _Complex v) {
    return complex_text(kv_toString_f32(crealf(v)), kv_toString_f32(cimagf(v)));
}

kv_String kv_toString_cd(double _Complex v) {
    return complex_text(kv_toString_f64(creal(v)), kv_toString_f64(cimag(v)));
}

kv_String kv_toString_cld(long double _Complex v) {
    return complex_text(kv_toString_f80(creall(v)), kv_toString_f80(cimagl(v)));
}

#ifdef __SIZEOF_INT128__
kv_String kv_toString_u128(unsigned __int128 v) {
    kv_String s = {{0}};
    char buf[132];
    digits(v, 10, false, buf);
    kv_string_append(&s, buf);
    return s;
}

kv_String kv_toString_i128(__int128 v) {
    kv_String s = {{0}};
    char buf[132];
    /* negate as unsigned so that the minimum value works too */
    digits(v < 0 ? (umax)0 - (umax)v : (umax)v, 10, false, buf);
    kv_string_append(&s, v < 0 ? "-" : "");
    kv_string_append(&s, buf);
    return s;
}
#endif

/* ---------- fmt: parsing ---------- */

/* Widths and precisions above this are rejected; a String holds 255
   bytes anyway. */
#define KV_FMT_MAX 4096

typedef struct {
    const char *format;
    size_t start; /* index of the conversion's '%' */
    size_t end;   /* index of the conversion character */
    char conv;
    bool minus, plus, space, hash, zero;
    int width; /* -1: none */
    int prec;  /* -1: none */
} Spec;

static bool parse_number(const char **p, int *out) {
    long n = 0;
    while (**p >= '0' && **p <= '9') {
        n = n * 10 + (**p - '0');
        if (n > KV_FMT_MAX)
            return false;
        (*p)++;
    }
    *out = (int)n;
    return true;
}

/* exactly one conversion (and any %%), with no length modifiers */
static bool parse_spec(const char *format, Spec *sp) {
    if (!format)
        return false;
    bool found = false;
    for (const char *p = format; *p; p++) {
        if (*p != '%')
            continue;
        if (p[1] == '%') {
            p++;
            continue;
        }
        if (found)
            return false;
        found = true;
        *sp = (Spec){.format = format, .start = (size_t)(p - format), .width = -1, .prec = -1};
        const char *q = p + 1;
        for (;; q++) {
            if (*q == '-')
                sp->minus = true;
            else if (*q == '+')
                sp->plus = true;
            else if (*q == ' ')
                sp->space = true;
            else if (*q == '#')
                sp->hash = true;
            else if (*q == '0')
                sp->zero = true;
            else
                break;
        }
        if (*q >= '0' && *q <= '9' && !parse_number(&q, &sp->width))
            return false;
        if (*q == '.') {
            q++;
            if (!parse_number(&q, &sp->prec))
                return false;
        }
        if (!*q || !strchr("diouxXcfFeEgGaAsp", *q))
            return false;
        sp->conv = *q;
        sp->end = (size_t)(q - format);
        p = q;
    }
    return found;
}

static bool is_int_conv(char c) { return strchr("diouxX", c) != NULL; }
static bool is_float_conv(char c) { return strchr("fFeEgGaA", c) != NULL; }

/* append format[from, to) with %% read as % */
static void append_literal(kv_String *s, const char *format, size_t from, size_t to) {
    char buf[2] = {0};
    for (size_t i = from; i < to; i++) {
        if (format[i] == '%' && i + 1 < to && format[i + 1] == '%')
            i++;
        buf[0] = format[i];
        kv_string_append(s, buf);
    }
}

/* the text around the conversion, with `field` in its place */
static kv_String assemble(const Spec *sp, const char *field) {
    kv_String s = {{0}};
    append_literal(&s, sp->format, 0, sp->start);
    kv_string_append(&s, field);
    append_literal(&s, sp->format, sp->end + 1, strlen(sp->format));
    return s;
}

static kv_String invalid(void) { return from_text("<invalid format>"); }

/* `prefix` (a sign or 0x) and `body` padded to the spec's width into out
   (KV_FMT_MAX + room for prefix and body); zero padding goes between
   prefix and body */
static void pad(const Spec *sp, const char *prefix, const char *body, bool zero_pad, char *out) {
    size_t lp = strlen(prefix), lb = strlen(body);
    size_t w = sp->width > 0 ? (size_t)sp->width : 0;
    size_t fill = w > lp + lb ? w - lp - lb : 0;
    char *o = out;
    if (!sp->minus && !zero_pad)
        for (size_t i = 0; i < fill; i++)
            *o++ = ' ';
    memcpy(o, prefix, lp);
    o += lp;
    if (!sp->minus && zero_pad)
        for (size_t i = 0; i < fill; i++)
            *o++ = '0';
    memcpy(o, body, lb);
    o += lb;
    if (sp->minus)
        for (size_t i = 0; i < fill; i++)
            *o++ = ' ';
    *o = '\0';
}

/* text for %s (and the conversions that print text): precision
   truncates, width pads, the other flags have no meaning */
static kv_String fmt_text(const Spec *sp, const char *text) {
    char body[KV_STRING_SIZE];
    char field[KV_FMT_MAX + KV_STRING_SIZE + 8];
    size_t n = strlen(text);
    if (n > sizeof body - 1)
        n = sizeof body - 1;
    if (sp->prec >= 0 && (size_t)sp->prec < n)
        n = (size_t)sp->prec;
    memcpy(body, text, n);
    body[n] = '\0';
    pad(sp, "", body, false, field);
    return assemble(sp, field);
}

/* An integer conversion of a value with magnitude `mag`, negative if
   `neg`, of `bits` width. An unsigned conversion of a negative value
   uses its two's complement in that width, as C does for the type. */
static kv_String fmt_int(const Spec *sp, bool neg, umax mag, int bits) {
    char field[2 * KV_FMT_MAX + 160];
    char conv = sp->conv;
    if (conv == 'c') {
        char body[2] = {(char)(neg ? (umax)0 - mag : mag), 0};
        if (!body[0])
            return assemble(sp, ""); /* a NUL character would end the String */
        pad(sp, "", body, false, field);
        return assemble(sp, field);
    }
    bool is_signed = conv == 'd' || conv == 'i';
    umax value = mag;
    if (!is_signed && neg) {
        umax mask = bits >= (int)(sizeof(umax) * 8) ? ~(umax)0 : (((umax)1 << bits) - 1);
        value = ((umax)0 - mag) & mask;
        neg = false;
    }
    int base = conv == 'o' ? 8 : (conv == 'x' || conv == 'X') ? 16 : 10;
    char num[140];
    digits(value, base, conv == 'X', num);
    if (sp->prec == 0 && value == 0)
        num[0] = '\0';
    /* precision is the minimum number of digits */
    char body[KV_FMT_MAX + 160];
    size_t nd = strlen(num);
    size_t zeros = sp->prec > 0 && (size_t)sp->prec > nd ? (size_t)sp->prec - nd : 0;
    if (conv == 'o' && sp->hash && zeros == 0 && num[0] != '0')
        zeros = 1; /* # makes octal start with 0 */
    memset(body, '0', zeros);
    strcpy(body + zeros, num);
    char prefix[4] = "";
    if (is_signed && neg)
        strcpy(prefix, "-");
    else if (is_signed && sp->plus)
        strcpy(prefix, "+");
    else if (is_signed && sp->space)
        strcpy(prefix, " ");
    if ((conv == 'x' || conv == 'X') && sp->hash && value != 0)
        strcat(prefix, conv == 'x' ? "0x" : "0X");
    pad(sp, prefix, body, sp->zero && sp->prec < 0, field);
    return assemble(sp, field);
}

/* A floating conversion, through a fresh format built from the parsed
   fields (all of which C defines for floating conversions). Only a long
   double is formatted as one: %La spells hex floats differently. */
static kv_String fmt_floating(const Spec *sp, long double v, bool is_long) {
    char field[3 * KV_FMT_MAX];
    char f[64];
    char *p = f;
    *p++ = '%';
    if (sp->minus)
        *p++ = '-';
    if (sp->plus)
        *p++ = '+';
    if (sp->space)
        *p++ = ' ';
    if (sp->hash)
        *p++ = '#';
    if (sp->zero)
        *p++ = '0';
    char *end = f + sizeof f;
    if (sp->width >= 0)
        p += snprintf(p, (size_t)(end - p), "%d", sp->width);
    if (sp->prec >= 0)
        p += snprintf(p, (size_t)(end - p), ".%d", sp->prec);
    snprintf(p, (size_t)(end - p), "%s%c", is_long ? "L" : "", sp->conv);
    int n = is_long ? snprintf(field, sizeof field, f, v) : snprintf(field, sizeof field, f, (double)v);
    if (n < 0)
        return invalid();
    return assemble(sp, field);
}

/* ---------- fmt: one entry point per kind of value ---------- */

static kv_String fmt_integer(bool neg, umax mag, int bits, const char *text, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (is_int_conv(sp.conv) || sp.conv == 'c')
        return fmt_int(&sp, neg, mag, bits);
    if (is_float_conv(sp.conv))
        return fmt_floating(&sp, neg ? -(long double)mag : (long double)mag, bits > 64);
    if (sp.conv == 's')
        return fmt_text(&sp, text);
    return invalid();
}

static kv_String fmt_signed(long long v, int bits, const char *format) {
    /* the magnitude of v without overflowing on the minimum value */
    umax mag = v < 0 ? (umax)(-(v + 1)) + 1 : (umax)v;
    return fmt_integer(v < 0, mag, bits, (const char *)kv_toString_i64(v).bytes, format);
}

static kv_String fmt_unsigned(unsigned long long v, const char *format) {
    return fmt_integer(false, v, 64, (const char *)kv_toString_u64(v).bytes, format);
}

kv_String kv_fmt_i8(signed char v, const char *format) { return fmt_signed(v, 8, format); }
kv_String kv_fmt_i16(short v, const char *format) { return fmt_signed(v, (int)sizeof(short) * 8, format); }
kv_String kv_fmt_i32(int v, const char *format) { return fmt_signed(v, (int)sizeof(int) * 8, format); }
kv_String kv_fmt_long(long v, const char *format) { return fmt_signed(v, (int)sizeof(long) * 8, format); }
kv_String kv_fmt_i64(long long v, const char *format) { return fmt_signed(v, 64, format); }
kv_String kv_fmt_u64(unsigned long long v, const char *format) { return fmt_unsigned(v, format); }

kv_String kv_fmt_char(char v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (sp.conv == 's')
        return fmt_text(&sp, (const char *)kv_toString_char(v).bytes);
    return fmt_signed(v, 8, format);
}

kv_String kv_fmt_bool(bool v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (sp.conv == 's')
        return fmt_text(&sp, v ? "true" : "false");
    return fmt_unsigned(v, format); /* converted: 0 or 1 */
}

static kv_String fmt_real(long double v, bool is_long, const char *text, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (is_float_conv(sp.conv))
        return fmt_floating(&sp, v, is_long);
    if (is_int_conv(sp.conv) || sp.conv == 'c') {
        /* to an integer only inside the range, as C requires */
        if (!(v >= -0x1p63L && v < 0x1p63L))
            return invalid();
        return fmt_signed((long long)v, 64, format);
    }
    if (sp.conv == 's')
        return fmt_text(&sp, text);
    return invalid();
}

kv_String kv_fmt_f32(float v, const char *format) {
    return fmt_real(v, false, (const char *)kv_toString_f32(v).bytes, format);
}

kv_String kv_fmt_f64(double v, const char *format) {
    return fmt_real(v, false, (const char *)kv_toString_f64(v).bytes, format);
}

kv_String kv_fmt_f80(long double v, const char *format) {
    return fmt_real(v, true, (const char *)kv_toString_f80(v).bytes, format);
}

static kv_String fmt_only_text(kv_String text, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp) || sp.conv != 's')
        return invalid();
    return fmt_text(&sp, (const char *)text.bytes);
}

kv_String kv_fmt_cf(float _Complex v, const char *format) { return fmt_only_text(kv_toString_cf(v), format); }
kv_String kv_fmt_cd(double _Complex v, const char *format) { return fmt_only_text(kv_toString_cd(v), format); }
kv_String kv_fmt_cld(long double _Complex v, const char *format) { return fmt_only_text(kv_toString_cld(v), format); }
kv_String kv_fmt_String(kv_String v, const char *format) { return fmt_only_text(v, format); }

kv_String kv_fmt_ptr(const void *v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (sp.conv == 'p' || sp.conv == 's')
        return fmt_text(&sp, (const char *)kv_toString_ptr(v).bytes);
    if (sp.conv == 'x' || sp.conv == 'X')
        return fmt_int(&sp, false, (umax)(uintptr_t)v, (int)sizeof(void *) * 8);
    return invalid();
}

kv_String kv_fmt_str(const char *v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (sp.conv == 's')
        return fmt_text(&sp, v ? v : "(null)");
    if (sp.conv == 'p')
        return kv_fmt_ptr(v, format);
    return invalid();
}

#ifdef __SIZEOF_INT128__
kv_String kv_fmt_u128(unsigned __int128 v, const char *format) {
    return fmt_integer(false, v, 128, (const char *)kv_toString_u128(v).bytes, format);
}

kv_String kv_fmt_i128(__int128 v, const char *format) {
    return fmt_integer(v < 0, v < 0 ? (umax)0 - (umax)v : (umax)v, 128, (const char *)kv_toString_i128(v).bytes,
                       format);
}
#endif

/* ---------- properties: .dec, .hex, .oct, .bin (#21) ---------- */

/* sign (signed types always have one), prefix, digits */
static uint8_t *number_text(bool is_signed, bool neg, umax mag, int base, uint8_t *buf) {
    const char *prefix = base == 16 ? "0x" : base == 8 ? "0o" : base == 2 ? "0b" : "";
    char num[132], text[140] = "";
    digits(mag, base, false, num);
    strcat(text, is_signed ? (neg ? "-" : "+") : "");
    strcat(text, prefix);
    strcat(text, num);
    strcpy((char *)buf, text); /* buf is sized for the type by kelvinc */
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
    strcpy((char *)buf, text); /* buf is sized for the type by kelvinc */
    return buf;
}

uint8_t *kv_dec_f32(float v, uint8_t *buf) { return float_text(v, "%+.9g", buf); }
uint8_t *kv_dec_f64(double v, uint8_t *buf) { return float_text(v, "%+.17g", buf); }
uint8_t *kv_hex_f32(float v, uint8_t *buf) { return float_text(v, "%+a", buf); }
uint8_t *kv_hex_f64(double v, uint8_t *buf) { return float_text(v, "%+a", buf); }

/* ---------- values of types kelvinc cannot see ---------- */

kv_String kv_toString_kind(const void *p, int kind) {
    switch (kind) {
    case KV_K_BOOL: return kv_toString_bool(*(const bool *)p);
    case KV_K_CHAR: return kv_toString_char(*(const char *)p);
    case KV_K_SCHAR: return kv_toString_i64(*(const signed char *)p);
    case KV_K_UCHAR: return kv_toString_u64(*(const unsigned char *)p);
    case KV_K_SHORT: return kv_toString_i64(*(const short *)p);
    case KV_K_USHORT: return kv_toString_u64(*(const unsigned short *)p);
    case KV_K_INT: return kv_toString_i64(*(const int *)p);
    case KV_K_UINT: return kv_toString_u64(*(const unsigned *)p);
    case KV_K_LONG: return kv_toString_i64(*(const long *)p);
    case KV_K_ULONG: return kv_toString_u64(*(const unsigned long *)p);
    case KV_K_LLONG: return kv_toString_i64(*(const long long *)p);
    case KV_K_ULLONG: return kv_toString_u64(*(const unsigned long long *)p);
#ifdef __SIZEOF_INT128__
    case KV_K_I128: return kv_toString_i128(*(const __int128 *)p);
    case KV_K_U128: return kv_toString_u128(*(const unsigned __int128 *)p);
#endif
    case KV_K_FLOAT: return kv_toString_f32(*(const float *)p);
    case KV_K_DOUBLE: return kv_toString_f64(*(const double *)p);
    case KV_K_LDOUBLE: return kv_toString_f80(*(const long double *)p);
    case KV_K_STR: return kv_toString_str(*(char *const *)p);
    case KV_K_CSTR: return kv_toString_str(*(const char *const *)p);
    case KV_K_STRING: return *(const kv_String *)p;
    default: return from_text("{...}");
    }
}
