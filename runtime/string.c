/* string.c - String, toString() and fmt() for the built-in types */
#include "kelvin_prelude.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

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

/* ---------- toString ---------- */

kv_String kv_toString_bool(bool v) { return from_text(v ? "true" : "false"); }

kv_String kv_toString_char(char v) {
    kv_String s = {{0}};
    s.bytes[0] = (unsigned char)v;
    return s;
}

kv_String kv_toString_i64(long long v) {
    kv_String s;
    snprintf((char *)s.bytes, sizeof s.bytes, "%lld", v);
    return s;
}

kv_String kv_toString_u64(unsigned long long v) {
    kv_String s;
    snprintf((char *)s.bytes, sizeof s.bytes, "%llu", v);
    return s;
}

kv_String kv_toString_f32(float v) {
    kv_String s;
    snprintf((char *)s.bytes, sizeof s.bytes, "%.9g", (double)v);
    return s;
}

kv_String kv_toString_f64(double v) {
    kv_String s;
    snprintf((char *)s.bytes, sizeof s.bytes, "%.17g", v);
    return s;
}

kv_String kv_toString_f80(long double v) {
    kv_String s;
    snprintf((char *)s.bytes, sizeof s.bytes, "%.21Lg", v);
    return s;
}

kv_String kv_toString_str(const char *v) { return from_text(v ? v : "(null)"); }

kv_String kv_toString_ptr(const void *v) {
    kv_String s;
    snprintf((char *)s.bytes, sizeof s.bytes, "%p", v);
    return s;
}

kv_String kv_toString_String(kv_String v) { return v; }

#ifdef __SIZEOF_INT128__
/* digits of v in base 8, 10 or 16, without a sign */
static void u128_digits(unsigned __int128 v, int base, bool upper, char *out, size_t size) {
    const char *digits = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    char buf[132];
    char *p = buf + sizeof buf;
    *--p = '\0';
    do {
        *--p = digits[(int)(v % (unsigned)base)];
        v /= (unsigned)base;
    } while (v);
    snprintf(out, size, "%s", p);
}

kv_String kv_toString_u128(unsigned __int128 v) {
    kv_String s;
    u128_digits(v, 10, false, (char *)s.bytes, sizeof s.bytes);
    return s;
}

kv_String kv_toString_i128(__int128 v) {
    if (v >= 0)
        return kv_toString_u128((unsigned __int128)v);
    kv_String s = from_text("-");
    char digits[64];
    /* negate as unsigned so that the minimum value works too */
    u128_digits((unsigned __int128)0 - (unsigned __int128)v, 10, false, digits, sizeof digits);
    kv_string_append(&s, digits);
    return s;
}
#endif

/* ---------- fmt ---------- */

/* The single conversion of a fmt() format: `head` is everything before
   the conversion character (leading text, '%', flags, width, precision),
   `conv` the conversion character, `tail` the text after it. */
typedef struct {
    char head[KV_STRING_SIZE * 2];
    char conv;
    const char *tail;
} Spec;

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
            return false; /* more than one conversion */
        const char *q = p + 1;
        q += strspn(q, "-+ #0");
        q += strspn(q, "0123456789");
        if (*q == '.') {
            q++;
            q += strspn(q, "0123456789");
        }
        /* no length modifiers: Kelvin supplies them */
        if (!*q || !strchr("diouxXcfFeEgGaAsp", *q))
            return false;
        size_t n = (size_t)(q - format);
        if (n >= sizeof sp->head)
            return false;
        memcpy(sp->head, format, n);
        sp->head[n] = '\0';
        sp->conv = *q;
        sp->tail = q + 1;
        found = true;
        p = q;
    }
    return found;
}

static bool is_int_conv(char c) { return strchr("diouxX", c) != NULL; }
static bool is_signed_conv(char c) { return c == 'd' || c == 'i'; }
static bool is_float_conv(char c) { return strchr("fFeEgGaA", c) != NULL; }

/* the format with `mod` inserted before the conversion character, and
   `conv` (or the original) as the conversion */
static void build(char *out, size_t size, const Spec *sp, const char *mod, char conv) {
    snprintf(out, size, "%s%s%c%s", sp->head, mod, conv ? conv : sp->conv, sp->tail);
}

static kv_String invalid(void) { return from_text("<invalid format>"); }

/* `%s` with the spec's flags and width, for text that stands in for the
   value (bool, toString). Precision means truncation for %s, which is
   what it means in C. The '0', '+', ' ' and '#' flags are not valid for
   %s and are dropped. */
static kv_String fmt_text(const Spec *sp, const char *text) {
    char head[sizeof sp->head];
    const char *pct = strrchr(sp->head, '%'); /* the conversion's '%' */
    size_t n = (size_t)(pct - sp->head) + 1;
    memcpy(head, sp->head, n);
    const char *q = pct + 1;
    bool minus = false;
    for (; *q && strchr("-+ #0", *q); q++)
        minus = minus || *q == '-';
    if (minus)
        head[n++] = '-';
    snprintf(head + n, sizeof head - n, "%s", q); /* width and precision */
    char format[KV_STRING_SIZE * 3];
    snprintf(format, sizeof format, "%ss%s", head, sp->tail);
    kv_String s;
    snprintf((char *)s.bytes, sizeof s.bytes, format, text);
    return s;
}

kv_String kv_fmt_i64(long long v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    char f[KV_STRING_SIZE * 3];
    kv_String s;
    if (is_int_conv(sp.conv)) {
        build(f, sizeof f, &sp, "ll", 0);
        if (is_signed_conv(sp.conv))
            snprintf((char *)s.bytes, sizeof s.bytes, f, v);
        else
            snprintf((char *)s.bytes, sizeof s.bytes, f, (unsigned long long)v);
    } else if (is_float_conv(sp.conv)) {
        build(f, sizeof f, &sp, "", 0);
        snprintf((char *)s.bytes, sizeof s.bytes, f, (double)v);
    } else if (sp.conv == 'c') {
        build(f, sizeof f, &sp, "", 0);
        snprintf((char *)s.bytes, sizeof s.bytes, f, (int)(unsigned char)v);
    } else if (sp.conv == 's') {
        return fmt_text(&sp, (const char *)kv_toString_i64(v).bytes);
    } else {
        return invalid();
    }
    return s;
}

kv_String kv_fmt_u64(unsigned long long v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    char f[KV_STRING_SIZE * 3];
    kv_String s;
    if (is_int_conv(sp.conv)) {
        /* an unsigned value prints unsigned, even with %d */
        build(f, sizeof f, &sp, "ll", is_signed_conv(sp.conv) ? 'u' : 0);
        snprintf((char *)s.bytes, sizeof s.bytes, f, v);
    } else if (is_float_conv(sp.conv)) {
        build(f, sizeof f, &sp, "", 0);
        snprintf((char *)s.bytes, sizeof s.bytes, f, (double)v);
    } else if (sp.conv == 'c') {
        build(f, sizeof f, &sp, "", 0);
        snprintf((char *)s.bytes, sizeof s.bytes, f, (int)(unsigned char)v);
    } else if (sp.conv == 's') {
        return fmt_text(&sp, (const char *)kv_toString_u64(v).bytes);
    } else {
        return invalid();
    }
    return s;
}

static kv_String fmt_float(long double v, const char *format, bool is_long, const char *text) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    char f[KV_STRING_SIZE * 3];
    kv_String s;
    if (is_float_conv(sp.conv)) {
        build(f, sizeof f, &sp, is_long ? "L" : "", 0);
        if (is_long)
            snprintf((char *)s.bytes, sizeof s.bytes, f, v);
        else
            snprintf((char *)s.bytes, sizeof s.bytes, f, (double)v);
    } else if (is_int_conv(sp.conv)) {
        /* converting to an integer is only defined inside the range */
        if (!(v > -9223372036854775809.0L && v < 9223372036854775808.0L))
            return invalid();
        return kv_fmt_i64((long long)v, format);
    } else if (sp.conv == 's') {
        return fmt_text(&sp, text);
    } else {
        return invalid();
    }
    return s;
}

kv_String kv_fmt_f32(float v, const char *format) {
    return fmt_float(v, format, false, (const char *)kv_toString_f32(v).bytes);
}

kv_String kv_fmt_f64(double v, const char *format) {
    return fmt_float(v, format, false, (const char *)kv_toString_f64(v).bytes);
}

kv_String kv_fmt_f80(long double v, const char *format) {
    return fmt_float(v, format, true, (const char *)kv_toString_f80(v).bytes);
}

kv_String kv_fmt_bool(bool v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (sp.conv == 's')
        return fmt_text(&sp, v ? "true" : "false");
    if (is_int_conv(sp.conv))
        return kv_fmt_i64(v, format);
    return invalid();
}

kv_String kv_fmt_char(char v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (sp.conv == 's')
        return fmt_text(&sp, (const char *)kv_toString_char(v).bytes);
    return kv_fmt_i64(v, format);
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

kv_String kv_fmt_ptr(const void *v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    char f[KV_STRING_SIZE * 3];
    kv_String s;
    if (sp.conv == 'p') {
        build(f, sizeof f, &sp, "", 0);
        snprintf((char *)s.bytes, sizeof s.bytes, f, v);
    } else if (sp.conv == 'x' || sp.conv == 'X') {
        build(f, sizeof f, &sp, "ll", 0);
        snprintf((char *)s.bytes, sizeof s.bytes, f, (unsigned long long)(uintptr_t)v);
    } else if (sp.conv == 's') {
        return fmt_text(&sp, (const char *)kv_toString_ptr(v).bytes);
    } else {
        return invalid();
    }
    return s;
}

kv_String kv_fmt_String(kv_String v, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (sp.conv == 's')
        return fmt_text(&sp, (const char *)v.bytes);
    return invalid();
}

#ifdef __SIZEOF_INT128__
/* 128-bit values that fit in 64 bits format like 64-bit ones; larger
   ones support d, i, u, o, x, X and s, with width and '-' only */
static kv_String fmt_big(bool negative, unsigned __int128 mag, const char *format) {
    Spec sp;
    if (!parse_spec(format, &sp))
        return invalid();
    if (is_float_conv(sp.conv)) {
        long double v = (long double)mag;
        return kv_fmt_f80(negative ? -v : v, format);
    }
    if (!is_int_conv(sp.conv) && sp.conv != 's')
        return invalid();
    int base = (sp.conv == 'o') ? 8 : (sp.conv == 'x' || sp.conv == 'X') ? 16 : 10;
    char text[160];
    char *p = text;
    if (negative && (sp.conv == 'd' || sp.conv == 'i' || sp.conv == 's'))
        *p++ = '-';
    u128_digits(mag, base, sp.conv == 'X', p, sizeof text - 1);
    return fmt_text(&sp, text);
}

kv_String kv_fmt_u128(unsigned __int128 v, const char *format) {
    if (v <= UINT64_MAX)
        return kv_fmt_u64((unsigned long long)v, format);
    return fmt_big(false, v, format);
}

kv_String kv_fmt_i128(__int128 v, const char *format) {
    if (v >= INT64_MIN && v <= INT64_MAX)
        return kv_fmt_i64((long long)v, format);
    if (v >= 0)
        return fmt_big(false, (unsigned __int128)v, format);
    return fmt_big(true, (unsigned __int128)0 - (unsigned __int128)v, format);
}
#endif

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
