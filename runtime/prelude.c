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

/* Floats show every digit their type holds (#259), as %.17g does for an
   f64 and %.9g for an f32, which is what the value really is: 0.1 is
   0.10000000000000001; trailing zeros go, and a decimal point stays, so
   they are never mistaken for integers and paste back as the value. As in
   Swift, a float is plain decimal from 0.0001 up to 2 to the power of
   its type's mantissa bits (2^53 for f64, 2^24 for f32), where every
   integer is exact, and has an exponent otherwise: 10.0, 0.0001,
   9007199254740992.0, but 1e-05 and 1e+16. The point is always '.',
   whatever the C locale's is. A NaN is "nan" whatever its sign bit
   (glibc would print "-nan" for 0.0 / 0.0 on x86).

   buf holds at least 96 bytes and comes in as the "%.*e" text of every
   digit (or "inf"), written with the locale's point; plain says whether the
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
    while (n > 1 && digits[n - 1] == '0') /* 1.0000000000000000e+00 is 1.0 */
        n--;
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

char *kv_f64_text(double v, char *buf) {
    if (isnan(v))
        return strcpy(buf, "nan");
    snprintf(buf, 62, "%.*e", DBL_DECIMAL_DIG - 1, v); /* every digit, 17 (#259) */
    return float_text(buf, fabs(v) <= ldexp(1, DBL_MANT_DIG));
}

char *kv_f32_text(float v, char *buf) {
    if (isnan(v))
        return strcpy(buf, "nan");
    snprintf(buf, 62, "%.*e", FLT_DECIMAL_DIG - 1, (double)v); /* 9 (#259) */
    return float_text(buf, fabsf(v) <= ldexpf(1, FLT_MANT_DIG));
}

char *kv_f80_text(long double v, char *buf) {
    if (isnan(v))
        return strcpy(buf, "nan");
    snprintf(buf, 94, "%.*Le", LDBL_DECIMAL_DIG - 1, v); /* 21 of x86's, 17 where it is a double (#259) */
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

/* each value's text to a FILE (an IO's fp, a void * in the prelude,
   #83), and to stdout for print */
void kv_fprint_char(void *fp, char v) { putc((unsigned char)v, (FILE *)fp); }
void kv_print_char(char v) { kv_fprint_char(stdout, v); }

void kv_fprint_i64(void *fp, long long v) { fprintf((FILE *)fp, "%lld", v); }
void kv_print_i64(long long v) { kv_fprint_i64(stdout, v); }

void kv_fprint_u64(void *fp, unsigned long long v) { fprintf((FILE *)fp, "%llu", v); }
void kv_print_u64(unsigned long long v) { kv_fprint_u64(stdout, v); }

void kv_fprint_bool(void *fp, bool v) { fputs(v ? "true" : "false", (FILE *)fp); }
void kv_print_bool(bool v) { kv_fprint_bool(stdout, v); }

void kv_fprint_str(void *fp, const char *v) { fputs(v ? v : "(null)", (FILE *)fp); }
void kv_print_str(const char *v) { kv_fprint_str(stdout, v); }

void kv_fprint_ptr(void *fp, const void *v) { fprintf((FILE *)fp, "%p", v); }
void kv_print_ptr(const void *v) { kv_fprint_ptr(stdout, v); }

void kv_fprint_newline(void *fp) { putc('\n', (FILE *)fp); }
void kv_print_newline(void) { kv_fprint_newline(stdout); }

void kv_fprint_f64(void *fp, double v) {
    char buf[96];
    fputs(kv_f64_text(v, buf), (FILE *)fp);
}
void kv_print_f64(double v) { kv_fprint_f64(stdout, v); }

void kv_fprint_f32(void *fp, float v) {
    char buf[96];
    fputs(kv_f32_text(v, buf), (FILE *)fp);
}
void kv_print_f32(float v) { kv_fprint_f32(stdout, v); }

void kv_fprint_f80(void *fp, long double v) {
    char buf[96];
    fputs(kv_f80_text(v, buf), (FILE *)fp);
}
void kv_print_f80(long double v) { kv_fprint_f80(stdout, v); }

#ifdef __SIZEOF_INT128__
void kv_fprint_u128(void *fp, unsigned __int128 v) {
    char buf[48];
    fputs(u128_text(v, buf), (FILE *)fp);
}
void kv_print_u128(unsigned __int128 v) { kv_fprint_u128(stdout, v); }

void kv_fprint_i128(void *fp, __int128 v) {
    char buf[48];
    fputs(i128_text(v, buf), (FILE *)fp);
}
void kv_print_i128(__int128 v) { kv_fprint_i128(stdout, v); }
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
    const char *t = kv_f64_text(v, buf);
    return put(p, max, t, strlen(t));
}

char *kv_template_f32(char *p, size_t max, float v) {
    char buf[96];
    const char *t = kv_f32_text(v, buf);
    return put(p, max, t, strlen(t));
}

char *kv_template_f80(char *p, size_t max, long double v) {
    char buf[96];
    const char *t = kv_f80_text(v, buf);
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

/* ---------- where kelvinc's printers of a value write (#123, #124) ---------- */

void kv_out_put(kv_out *o, const void *text) {
    if (o->s)
        kv_string_append_text(o->s, text);
    else
        fputs((const char *)text, o->fp ? (FILE *)o->fp : stdout);
}

/* "text" in full, escaped as in .cstr: \" \\ \n \r \t, other controls as
   \u00XX, and for bytes past ASCII \xNN, so the text stays UTF-8 */
void kv_out_quoted(kv_out *o, const uint8_t *at, size_t n, bool bytes) {
    char run[256];
    size_t k = 0;
    run[k++] = '"';
    for (size_t i = 0; i < n; i++) {
        uint8_t c = at[i];
        char e[8];
        if (c == '"' || c == '\\')
            snprintf(e, sizeof e, "\\%c", c);
        else if (c == '\n')
            snprintf(e, sizeof e, "\\n");
        else if (c == '\r')
            snprintf(e, sizeof e, "\\r");
        else if (c == '\t')
            snprintf(e, sizeof e, "\\t");
        else if (c < 0x20 || c == 0x7F)
            snprintf(e, sizeof e, bytes ? "\\x%02x" : "\\u%04x", c);
        else if (bytes && c >= 0x80)
            snprintf(e, sizeof e, "\\x%02x", c);
        else
            e[0] = (char)c, e[1] = 0;
        size_t m = strlen(e);
        if (k + m + 2 > sizeof run) {
            run[k] = 0;
            kv_out_put(o, run);
            k = 0;
        }
        memcpy(run + k, e, m);
        k += m;
    }
    run[k++] = '"';
    run[k] = 0;
    kv_out_put(o, run);
}

void kv_out_quoted_text(kv_out *o, const void *s) {
    if (!s)
        kv_out_put(o, "nullptr"); /* as Kelvin writes it (#259) */
    else
        kv_out_quoted(o, (const uint8_t *)s, strlen((const char *)s), false);
}

int kv_out_width(long long n) { return n < 0 ? 0 : n > 10 ? 10 : (int)n; }

/* a line, indented by width spaces a level (#124, #127) */
static void out_line(kv_out *o, int level) {
    static const char spaces[] = "          ";
    kv_out_put(o, "\n");
    for (int i = 0; i < level; i++)
        kv_out_put(o, spaces + 10 - (o->width < 0 ? 0 : o->width > 10 ? 10 : o->width));
}

void kv_out_sep(kv_out *o, int level, bool first) {
    if (!first)
        kv_out_put(o, level < 0 ? ", " : ",");
    if (level >= 0)
        out_line(o, level + 1);
}

void kv_out_end(kv_out *o, int level) {
    if (level >= 0)
        out_line(o, level);
}

