/* .cstr's runtime from C (#22): every kind of value, and the edges */
#include <kelvin_prelude.h>
#include <complex.h>
#include <float.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#define CSTR(v, buf) _Generic((v), KV_PROPERTY_cstr default: kv_cstr_ptr)(v, buf)
#define CHK(got, want) do { const char *g_ = (const char *)(got); \
    if (strcmp(g_, want)) printf("MISMATCH %s: got [%s] want [%s]\n", #got, g_, want); else n_ok++; } while (0)

int main(void)
{
    int n_ok = 0;
    uint8_t b[KV_CSTR_SCALAR];
    CHK(CSTR(LLONG_MIN, b), "-9223372036854775808");
    CHK(CSTR(ULLONG_MAX, b), "18446744073709551615");
    CHK(CSTR((signed char)-128, b), "-128");
    CHK(CSTR((unsigned char)255, b), "255");
    __int128 lo = -(__int128)(((unsigned __int128)1 << 127) - 1) - 1;
    CHK(CSTR(lo, b), "-170141183460469231731687303715884105728");
    CHK(CSTR(~(unsigned __int128)0, b), "340282366920938463463374607431768211455");
    CHK(CSTR(-DBL_MIN, b), "-2.2250738585072014e-308");
    CHK(CSTR(-FLT_MIN, b), "-1.17549435e-38");
    /* long double's width varies by platform; its 21 digits always fit */
    if (!strncmp((const char *)CSTR(-LDBL_MAX, b), "-1.", 3) && strlen((const char *)b) <= 29) n_ok++;
    else printf("MISMATCH long double: %s\n", b);
    CHK(CSTR(-NAN, b), "nan");
    CHK(CSTR(-INFINITY, b), "-inf");
    CHK(CSTR((_Bool)1, b), "true");
    CHK(CSTR('A', b), "65"); /* a character constant is an int in C */
    CHK(CSTR((char)'A', b), "A");
    double _Complex z = 1.5 - 2.0 * I;
    CHK(CSTR(z, b), "1.5-2i");
    long double _Complex lz = -LDBL_MAX + -LDBL_MAX * I;
    if (strlen((const char *)CSTR(lz, b)) < KV_CSTR_SCALAR) n_ok++; else printf("MISMATCH long double complex\n");
    char *s = "text";
    if (CSTR(s, b) == (uint8_t *)s) n_ok++; else printf("MISMATCH a string is its own text\n");
    const char *cs0 = "const";
    if (_Generic(CSTR(cs0, b), const uint8_t *: 1, default: 0)) n_ok++; else printf("MISMATCH const string lost const\n");
    CHK(CSTR((char *)0, b), "(null)");
    CHK(CSTR((void *)0, b), "0x0");
    CHK(CSTR((void *)0xbeef, b), "0xbeef");

    /* the derived text's pieces */
    uint8_t t[128];
    uint8_t *p = kv_cstr_put(t, "{s: ");
    p = kv_cstr_put_str(p, "0123456789012345678901234567890123456789012345678901234567890");
    p = kv_cstr_put(p, "}");
    CHK(t, "{s: 012345678901234567890123456789012345678901234567890123456...}");
    p = kv_cstr_put_str(t, "012345678901234567890123456789012345678901234567890123456789");
    if (p - t == KV_CSTR_STR) n_ok++; else printf("MISMATCH a string of exactly KV_CSTR_STR bytes\n");
    unsigned long ul = 7;
    const char *cs = "c";
    struct { int a; } opaque = {1};
    struct { char label[16]; char full[4]; } arrays = {"hello", {'a', 'b', 'c', 'd'}};
    CHK(kv_cstr_any(arrays.label, b), "hello");
    CHK(kv_cstr_any(arrays.full, b), "abcd");
    CHK(kv_cstr_any(ul, b), "7");
    CHK(kv_cstr_any(cs, b), "c");
    CHK(kv_cstr_any(opaque, b), "{...}");
    printf("%d checks ok\n", n_ok);
    return 0;
}
// out: 28 checks ok
