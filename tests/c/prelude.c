/* libkelvin used from C: linked statically and dynamically by tests/run.sh */
#include <kelvin_prelude.h>
#include <float.h>
#include <math.h>
#include <string.h>

int main(void)
{
    long long n = -42;
    /* in C, true is the int 1, so cast it to print true */
    println("from C: ", n, " ", 2.5, " ", (unsigned char)200, " ", (bool)true, " ", true);
    println();

    /* long double shows as f64 does, plain up to 2 to the power of its
       mantissa bits, LDBL_MANT_DIG, which varies by platform: 64 for
       x87's 80-bit format, 53 where long double is double (as on Apple's
       arm64), 113 for IEEE quad (as on arm64 Linux) */
    println(10.0L, " ", 1500.0L, " ", 1e15L, " ", 0.0001L, " ", 1e-5L, " ", 1e300L);
    println(-1500.25L, " ", 0.0015L, " ", -0.0015L, " ", -1.25e-300L);
    kv_template top = {0}, above = {0};
    kv_template_f80(&top, ldexpl(1, LDBL_MANT_DIG));
    kv_template_f80(&above, nextafterl(ldexpl(1, LDBL_MANT_DIG), INFINITY));
    const char *t = (const char *)top.text;
    println((bool)(!strchr(t, 'e') && !strcmp(t + strlen(t) - 2, ".0")), " ",
            (bool)strchr((const char *)above.text, 'e'));
    kv_template_free(&top);
    kv_template_free(&above);
    return 0;
}
// out: from C: -42 2.5 200 true 1
// out: 
// out: 10.0 1500.0 1000000000000000.0 0.0001 1e-05 1e+300
// out: -1500.25 0.0015 -0.0015 -1.25e-300
// out: true true
