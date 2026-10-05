/* KV_TEMPLATE_BOUND (#44) against the longest text libkelvin's template
   writers give each type, so that a bound too small for any type fails
   here, as kelvinc's static assertion relies on it */
#include <kelvin_prelude.h>
#include <float.h>
#include <limits.h>
#include <stdio.h>

static int failures = 0;

/* the text the writer made from buf to end must fit the type's bound */
static void fits(const char *what, char *buf, char *end, size_t bound)
{
    size_t n = (size_t)(end - buf);
    if (n > bound) {
        printf("%s: %zu bytes, bound %zu\n", what, n, bound);
        failures++;
    }
}

#define LONGEST(what, writer, T, ...) \
    do { \
        T vs[] = {__VA_ARGS__}; \
        for (size_t i = 0; i < sizeof vs / sizeof vs[0]; i++) { \
            char buf[256]; \
            fits(what, buf, writer(buf, sizeof buf - 1, vs[i]), KV_TEMPLATE_BOUND(vs[i])); \
        } \
    } while (0)

int main(void)
{
    LONGEST("bool", kv_template_bool, bool, false, true);
    LONGEST("char", kv_template_char, char, 'x');
    LONGEST("signed char", kv_template_i64, signed char, SCHAR_MIN, SCHAR_MAX);
    LONGEST("short", kv_template_i64, short, SHRT_MIN, SHRT_MAX);
    LONGEST("int", kv_template_i64, int, INT_MIN, INT_MAX);
    LONGEST("long", kv_template_i64, long, LONG_MIN, LONG_MAX);
    LONGEST("long long", kv_template_i64, long long, LLONG_MIN, LLONG_MAX);
    LONGEST("unsigned char", kv_template_u64, unsigned char, UCHAR_MAX);
    LONGEST("unsigned short", kv_template_u64, unsigned short, USHRT_MAX);
    LONGEST("unsigned", kv_template_u64, unsigned, UINT_MAX);
    LONGEST("unsigned long", kv_template_u64, unsigned long, ULONG_MAX);
    LONGEST("unsigned long long", kv_template_u64, unsigned long long, ULLONG_MAX);
#ifdef __SIZEOF_INT128__
    LONGEST("__int128", kv_template_i128, __int128, -(__int128)(((unsigned __int128)1 << 127) - 1) - 1);
    LONGEST("unsigned __int128", kv_template_u128, unsigned __int128, ~(unsigned __int128)0);
#endif
    LONGEST("float", kv_template_f32, float, -FLT_MIN, -FLT_MAX, -FLT_TRUE_MIN, -1.17549435e-38f, -16777216.0f,
            -0.000123456789f, -9.99999944e-05f, 1.0f / 0.0f, -1.0f / 0.0f, 0.0f / 0.0f);
    LONGEST("double", kv_template_f64, double, -DBL_MIN, -DBL_MAX, -DBL_TRUE_MIN, -2.2250738585072014e-308,
            -9007199254740992.0, -0.00012345678901234567, -9.9999999999999991e-05, -123456789012345.67);
    LONGEST("long double", kv_template_f80, long double, -LDBL_MIN, -LDBL_MAX, -LDBL_TRUE_MIN,
            -0.000123456789012345678901234567890123L, -1.23456789012345678901234567890123e-4000L);
    int x = 0;
    LONGEST("pointer", kv_template_ptr, const void *, &x, (const void *)0, (const void *)~(uintptr_t)0);
    printf(failures ? "%d too long\n" : "every bound holds\n", failures);
    return failures != 0;
}
// out: every bound holds
