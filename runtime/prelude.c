/* prelude.c - the Kelvin prelude: print() and println()

   Built into libkelvin.a and libkelvin.so / libkelvin.dylib. Output goes
   through stdio, so it interleaves correctly with printf. */
#include "kelvin_prelude.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void kv_print_char(char v) { putchar((unsigned char)v); }

void kv_print_i64(long long v) { printf("%lld", v); }

void kv_print_u64(unsigned long long v) { printf("%llu", v); }

void kv_print_bool(bool v) { fputs(v ? "true" : "false", stdout); }

void kv_print_str(const char *v) { fputs(v ? v : "(null)", stdout); }

void kv_print_ptr(const void *v) { printf("%p", v); }

void kv_print_String(kv_String v) { fputs((const char *)v.bytes, stdout); }

void kv_print_newline(void) { putchar('\n'); }

/* Floats print in the shortest form that reads back as the same value,
   with a decimal point so they are never mistaken for integers. A NaN
   prints as "nan" whatever its sign bit (glibc would print "-nan" for
   0.0 / 0.0 on x86). */
static void print_float_text(char *buf) {
    if (!strpbrk(buf, ".eEn")) /* not 1e9, nan or inf */
        strcat(buf, ".0");
    fputs(buf, stdout);
}

void kv_print_f64(double v) {
    if (isnan(v)) {
        fputs("nan", stdout);
        return;
    }
    char buf[64];
    for (int p = 1; p <= 17; p++) {
        snprintf(buf, sizeof buf - 2, "%.*g", p, v);
        if (strtod(buf, NULL) == v)
            break;
    }
    print_float_text(buf);
}

void kv_print_f32(float v) {
    if (isnan(v)) {
        fputs("nan", stdout);
        return;
    }
    char buf[64];
    for (int p = 1; p <= 9; p++) {
        snprintf(buf, sizeof buf - 2, "%.*g", p, (double)v);
        if (strtof(buf, NULL) == v)
            break;
    }
    print_float_text(buf);
}

void kv_print_f80(long double v) {
    if (isnan(v)) {
        fputs("nan", stdout);
        return;
    }
    char buf[96];
    for (int p = 1; p <= 36; p++) {
        snprintf(buf, sizeof buf - 2, "%.*Lg", p, v);
        if (strtold(buf, NULL) == v)
            break;
    }
    print_float_text(buf);
}

#ifdef __SIZEOF_INT128__
void kv_print_u128(unsigned __int128 v) {
    char buf[40];
    char *p = buf + sizeof buf;
    *--p = '\0';
    do {
        *--p = (char)('0' + (int)(v % 10));
        v /= 10;
    } while (v);
    fputs(p, stdout);
}

void kv_print_i128(__int128 v) {
    if (v < 0) {
        putchar('-');
        /* negate as unsigned so that the minimum value works too */
        kv_print_u128((unsigned __int128)0 - (unsigned __int128)v);
    } else {
        kv_print_u128((unsigned __int128)v);
    }
}
#endif
