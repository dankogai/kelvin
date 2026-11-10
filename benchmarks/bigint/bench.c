/* bench.c - GMP's mpz_t, the cases of bench.k, best of 3; run.sh builds it
   with cc -O2 against GMP.  Each line is a case's id, its best time in
   seconds and its result mod 1000000007. */
#define _GNU_SOURCE     /* CLOCK_MONOTONIC_RAW, a nanosecond clock on Linux and macOS */
#include <gmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static char digits10k[10001];
static mpz_t gA, gB, gBig, gPow, gX, gY, gMod, gBase, gExp;

static double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static void case_sum(mpz_t r) {
    mpz_set_ui(r, 0);
    for (unsigned long i = 1; i <= 100000; i++) mpz_add_ui(r, r, i);
}

static void case_fib(mpz_t r) {     /* 10,000 additions: a is fib(10000) */
    mpz_t a, b;
    mpz_init_set_ui(a, 0);
    mpz_init_set_ui(b, 1);
    for (int i = 0; i < 5000; i++) {
        mpz_add(a, a, b);
        mpz_add(b, b, a);
    }
    mpz_set(r, a);
    mpz_clears(a, b, NULL);
}

static void case_factorial(mpz_t r) {
    mpz_set_ui(r, 1);
    for (unsigned long i = 2; i <= 1000; i++) mpz_mul_ui(r, r, i);
}

static void case_power(mpz_t r) { mpz_ui_pow_ui(r, 2, 100000); }

static void case_mul(mpz_t r) {
    for (int i = 0; i < 100; i++) mpz_mul(r, gA, gB);
}

static void case_div(mpz_t r) {
    for (int i = 0; i < 100; i++) mpz_tdiv_q(r, gBig, gB);
}

static void case_powmod(mpz_t r) { mpz_powm(r, gBase, gExp, gMod); }

static void case_gcd(mpz_t r) {
    for (int i = 0; i < 10; i++) mpz_gcd(r, gX, gY);
}

static void case_isqrt(mpz_t r) {
    for (int i = 0; i < 10; i++) mpz_sqrt(r, gBig);
}

static void case_tostr(mpz_t r) {
    char *s = mpz_get_str(NULL, 10, gPow);
    mpz_set_ui(r, strlen(s));
    free(s);
}

static void case_parse(mpz_t r) {
    for (int i = 0; i < 100; i++) mpz_set_str(r, digits10k, 10);
}

static void bench(const char *id, void (*f)(mpz_t)) {
    double best = 1e300;
    unsigned long check = 0;
    for (int i = 0; i < 3; i++) {
        mpz_t r;
        mpz_init(r);
        double t0 = now();
        f(r);
        double t = now() - t0;
        if (t < best) best = t;
        check = mpz_fdiv_ui(r, 1000000007);
        mpz_clear(r);
    }
    printf("%s\t%.9f\t%lu\n", id, best, check);
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--version") == 0) {
        printf("%s\n", gmp_version);
        return 0;
    }
    for (int i = 0; i < 1000; i++) memcpy(digits10k + i * 10, "9876543210", 10);
    char digits620[621];
    for (int i = 0; i < 62; i++) memcpy(digits620 + i * 10, "9876543210", 10);
    digits620[620] = '\0';
    mpz_inits(gA, gB, gBig, gPow, gX, gY, gMod, gBase, gExp, NULL);
    mpz_set_str(gA, digits10k, 10);
    mpz_add_ui(gB, gA, 1);
    mpz_mul(gBig, gA, gA);
    mpz_ui_pow_ui(gPow, 2, 100000);
    mpz_ui_pow_ui(gX, 7, 1183);
    mpz_ui_pow_ui(gY, 3, 2093);
    mpz_set_str(gMod, digits620, 10);
    mpz_add_ui(gMod, gMod, 1);
    mpz_sub_ui(gBase, gMod, 12346);
    mpz_fdiv_q_2exp(gExp, gMod, 1);

    bench("sum", case_sum);
    bench("fib", case_fib);
    bench("factorial", case_factorial);
    bench("power", case_power);
    bench("mul", case_mul);
    bench("div", case_div);
    bench("powmod", case_powmod);
    bench("gcd", case_gcd);
    bench("isqrt", case_isqrt);
    bench("tostr", case_tostr);
    bench("parse", case_parse);
    mpz_clears(gA, gB, gBig, gPow, gX, gY, gMod, gBase, gExp, NULL);
    return 0;
}
