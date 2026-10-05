/* prelude.c - the Kelvin prelude: print() and println(), and the text of
   template literals (#39), which shows each value as print does, written
   into storage the caller gives: nothing here allocates

   Built into libkelvin.a and libkelvin.so / libkelvin.dylib. Output goes
   through stdio, so it interleaves correctly with printf. */
#include "kelvin_prelude.h"

#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------- the text of a value, as print shows it ---------- */

/* Floats show in the shortest form that reads back as the same value,
   with a decimal point so they are never mistaken for integers. As in
   Swift, a float is plain decimal from 0.0001 up to 2 to the power of
   its type's mantissa bits (2^53 for f64, 2^24 for f32), where every
   integer is exact, and has an exponent otherwise: 10.0, 0.0001,
   9007199254740992.0, but 1e-05 and 1e+16. The point is always '.',
   whatever the C locale's is. A NaN is "nan" whatever its sign bit
   (glibc would print "-nan" for 0.0 / 0.0 on x86).

   buf holds at least 96 bytes and comes in as the shortest "%.*e" text
   (or "inf"), written with the locale's point; plain says whether the
   value is within 2^mantissa bits. */
static char *float_text(char *buf, bool plain) {
    char *e = strchr(buf, 'e');
    if (!e)
        return buf;
    int x = atoi(e + 1);
    char digits[48];
    int n = 0;
    for (char *s = buf; s < e; s++)
        if (*s >= '0' && *s <= '9')
            digits[n++] = *s;
    char *p = buf + (buf[0] == '-');
    if (!plain || x < -4) {
        /* "1,5e+16" in a German locale becomes "1.5e+16" */
        for (int i = 0; i < n; i++) {
            *p++ = digits[i];
            if (i == 0 && n > 1)
                *p++ = '.';
        }
        snprintf(p, 8, "e%+03d", x);
        return buf;
    }
    /* "-1.5e+03" becomes "-1500.0", and "1.5e-03" "0.0015" */
    if (x < 0) {
        *p++ = '0';
        *p++ = '.';
        for (int i = -1; i > x; i--)
            *p++ = '0';
        for (int i = 0; i < n; i++)
            *p++ = digits[i];
    } else {
        for (int i = 0; i <= x; i++)
            *p++ = i < n ? digits[i] : '0';
        *p++ = '.';
        if (n <= x + 1)
            *p++ = '0';
        for (int i = x + 1; i < n; i++)
            *p++ = digits[i];
    }
    *p = '\0';
    return buf;
}

static char *f64_text(double v, char *buf) {
    if (isnan(v))
        return strcpy(buf, "nan");
    for (int p = 1; p <= 17; p++) {
        snprintf(buf, 62, "%.*e", p - 1, v);
        if (strtod(buf, NULL) == v)
            break;
    }
    return float_text(buf, fabs(v) <= ldexp(1, DBL_MANT_DIG));
}

static char *f32_text(float v, char *buf) {
    if (isnan(v))
        return strcpy(buf, "nan");
    for (int p = 1; p <= 9; p++) {
        snprintf(buf, 62, "%.*e", p - 1, (double)v);
        if (strtof(buf, NULL) == v)
            break;
    }
    return float_text(buf, fabsf(v) <= ldexpf(1, FLT_MANT_DIG));
}

static char *f80_text(long double v, char *buf) {
    if (isnan(v))
        return strcpy(buf, "nan");
    for (int p = 1; p <= 36; p++) {
        snprintf(buf, 94, "%.*Le", p - 1, v);
        if (strtold(buf, NULL) == v)
            break;
    }
    return float_text(buf, fabsl(v) <= ldexpl(1, LDBL_MANT_DIG));
}

#ifdef __SIZEOF_INT128__
static char *u128_text(unsigned __int128 v, char *buf) {
    char *p = buf + 40;
    *--p = '\0';
    do {
        *--p = (char)('0' + (int)(v % 10));
        v /= 10;
    } while (v);
    return p;
}

static char *i128_text(__int128 v, char *buf) {
    if (v >= 0)
        return u128_text((unsigned __int128)v, buf);
    /* negate as unsigned so that the minimum value works too */
    char *p = u128_text((unsigned __int128)0 - (unsigned __int128)v, buf + 1);
    *--p = '-';
    return p;
}
#endif

/* ---------- print ---------- */

void kv_print_char(char v) { putchar((unsigned char)v); }

void kv_print_i64(long long v) { printf("%lld", v); }

void kv_print_u64(unsigned long long v) { printf("%llu", v); }

void kv_print_bool(bool v) { fputs(v ? "true" : "false", stdout); }

void kv_print_str(const char *v) { fputs(v ? v : "(null)", stdout); }

void kv_print_ptr(const void *v) { printf("%p", v); }

void kv_print_newline(void) { putchar('\n'); }

void kv_print_f64(double v) {
    char buf[96];
    fputs(f64_text(v, buf), stdout);
}

void kv_print_f32(float v) {
    char buf[96];
    fputs(f32_text(v, buf), stdout);
}

void kv_print_f80(long double v) {
    char buf[96];
    fputs(f80_text(v, buf), stdout);
}

#ifdef __SIZEOF_INT128__
void kv_print_u128(unsigned __int128 v) {
    char buf[48];
    fputs(u128_text(v, buf), stdout);
}

void kv_print_i128(__int128 v) {
    char buf[48];
    fputs(i128_text(v, buf), stdout);
}
#endif

/* ---------- template literals (#39) ---------- */

/* Puts at most max bytes of the n bytes at s, and returns the end. The
   writers of numbers, bools and pointers never need the cut: kelvinc
   makes room for their longest text, which C checks (KV_TEMPLATE_VALUE) */
static char *put(char *p, size_t max, const char *s, size_t n) {
    n = n < max ? n : max;
    memcpy(p, s, n);
    return p + n;
}

char *kv_template_part(char *p, const char *s, size_t n) {
    memcpy(p, s, n);
    return p + n;
}

char *kv_template_copy(char *storage, const char *built, const char *end) {
    size_t n = (size_t)(end - built);
    memcpy(storage, built, n);
    storage[n] = '\0';
    return storage;
}

char *kv_template_char(char *p, size_t max, char v) { return put(p, max, &v, 1); }

char *kv_template_i64(char *p, size_t max, long long v) {
    char buf[32];
    return put(p, max, buf, (size_t)snprintf(buf, sizeof buf, "%lld", v));
}

char *kv_template_u64(char *p, size_t max, unsigned long long v) {
    char buf[32];
    return put(p, max, buf, (size_t)snprintf(buf, sizeof buf, "%llu", v));
}

char *kv_template_bool(char *p, size_t max, bool v) { return v ? put(p, max, "true", 4) : put(p, max, "false", 5); }

/* At most max bytes of the text at v, which ends at a NUL or after n
   bytes: a longer one shows its first max - 3 bytes and "...". It is
   read no further than max + 1 or n bytes. */
static char *cut(char *p, size_t max, const char *v, size_t n) {
    size_t len = 0;
    while (len <= max && len < n && v[len])
        len++;
    if (len <= max)
        return put(p, max, v, len);
    size_t keep = max > 3 ? max - 3 : 0; /* a caller from C may give a max below 3 */
    p = put(p, keep, v, keep);
    return put(p, max - keep, "...", 3);
}

char *kv_template_str(char *p, size_t max, const char *v) {
    return v ? cut(p, max, v, (size_t)-1) : put(p, max, "(null)", 6);
}

char *kv_template_bytes(char *p, size_t max, size_t n, const void *v) { return cut(p, max, v, n); }

char *kv_template_ptr(char *p, size_t max, const void *v) {
    char buf[40];
    int n = snprintf(buf, sizeof buf, "%p", v);
    return put(p, max, buf, n < (int)sizeof buf ? (size_t)n : sizeof buf - 1);
}

char *kv_template_f64(char *p, size_t max, double v) {
    char buf[96];
    const char *t = f64_text(v, buf);
    return put(p, max, t, strlen(t));
}

char *kv_template_f32(char *p, size_t max, float v) {
    char buf[96];
    const char *t = f32_text(v, buf);
    return put(p, max, t, strlen(t));
}

char *kv_template_f80(char *p, size_t max, long double v) {
    char buf[96];
    const char *t = f80_text(v, buf);
    return put(p, max, t, strlen(t));
}

#ifdef __SIZEOF_INT128__
char *kv_template_u128(char *p, size_t max, unsigned __int128 v) {
    char buf[48];
    const char *t = u128_text(v, buf);
    return put(p, max, t, strlen(t));
}

char *kv_template_i128(char *p, size_t max, __int128 v) {
    char buf[48];
    const char *t = i128_text(v, buf);
    return put(p, max, t, strlen(t));
}
#endif
