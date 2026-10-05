/* prelude.c - the Kelvin prelude: print() and println(), and the text of
   template literals (#39), which shows each value as print does

   Built into libkelvin.a and libkelvin.so / libkelvin.dylib. Output goes
   through stdio, so it interleaves correctly with printf. */
#include "kelvin_prelude.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------- the text of a value, as print shows it ---------- */

/* Floats show in the shortest form that reads back as the same value,
   with a decimal point so they are never mistaken for integers. A NaN
   is "nan" whatever its sign bit (glibc would print "-nan" for
   0.0 / 0.0 on x86). buf holds at least 96 bytes. */
static char *float_text(char *buf) {
    if (!strpbrk(buf, ".eEn")) /* not 1e9, nan or inf */
        strcat(buf, ".0");
    return buf;
}

static char *f64_text(double v, char *buf) {
    if (isnan(v))
        return strcpy(buf, "nan");
    for (int p = 1; p <= 17; p++) {
        snprintf(buf, 62, "%.*g", p, v);
        if (strtod(buf, NULL) == v)
            break;
    }
    return float_text(buf);
}

static char *f32_text(float v, char *buf) {
    if (isnan(v))
        return strcpy(buf, "nan");
    for (int p = 1; p <= 9; p++) {
        snprintf(buf, 62, "%.*g", p, (double)v);
        if (strtof(buf, NULL) == v)
            break;
    }
    return float_text(buf);
}

static char *f80_text(long double v, char *buf) {
    if (isnan(v))
        return strcpy(buf, "nan");
    for (int p = 1; p <= 36; p++) {
        snprintf(buf, 94, "%.*Lg", p, v);
        if (strtold(buf, NULL) == v)
            break;
    }
    return float_text(buf);
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

/* Appends n bytes of s, keeping the text NUL-terminated */
static void append(kv_template *t, const char *s, size_t n) {
    if (t->len + n + 1 > t->cap) {
        size_t cap = t->cap ? t->cap : 64;
        while (cap < t->len + n + 1)
            cap *= 2;
        uint8_t *text = realloc(t->text, cap);
        if (!text) {
            fputs("kelvin: out of memory for a template literal\n", stderr);
            abort();
        }
        t->text = text;
        t->cap = cap;
    }
    memcpy(t->text + t->len, s, n);
    t->len += n;
    t->text[t->len] = '\0';
}

void kv_template_free(kv_template *t) {
    free(t->text);
    *t = (kv_template){0};
}

/* The built text replaces the earlier one in the template's storage */
char *kv_template_take(kv_template *storage, kv_template *built) {
    if (!built->text)
        append(built, "", 0);
    free(storage->text);
    *storage = *built;
    *built = (kv_template){0};
    return (char *)storage->text;
}

void kv_template_part(kv_template *t, const char *s, size_t n) { append(t, s, n); }

void kv_template_char(kv_template *t, char v) { append(t, &v, 1); }

void kv_template_i64(kv_template *t, long long v) {
    char buf[32];
    append(t, buf, (size_t)snprintf(buf, sizeof buf, "%lld", v));
}

void kv_template_u64(kv_template *t, unsigned long long v) {
    char buf[32];
    append(t, buf, (size_t)snprintf(buf, sizeof buf, "%llu", v));
}

void kv_template_bool(kv_template *t, bool v) { kv_template_str(t, v ? "true" : "false"); }

void kv_template_str(kv_template *t, const char *v) {
    v = v ? v : "(null)";
    append(t, v, strlen(v));
}

void kv_template_ptr(kv_template *t, const void *v) {
    char buf[40];
    append(t, buf, (size_t)snprintf(buf, sizeof buf, "%p", v));
}

void kv_template_f64(kv_template *t, double v) {
    char buf[96];
    kv_template_str(t, f64_text(v, buf));
}

void kv_template_f32(kv_template *t, float v) {
    char buf[96];
    kv_template_str(t, f32_text(v, buf));
}

void kv_template_f80(kv_template *t, long double v) {
    char buf[96];
    kv_template_str(t, f80_text(v, buf));
}

#ifdef __SIZEOF_INT128__
void kv_template_u128(kv_template *t, unsigned __int128 v) {
    char buf[48];
    kv_template_str(t, u128_text(v, buf));
}

void kv_template_i128(kv_template *t, __int128 v) {
    char buf[48];
    kv_template_str(t, i128_text(v, buf));
}
#endif
