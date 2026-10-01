/* kelvin_prelude.h - the Kelvin prelude, available to every Kelvin program

   kelvinc includes this header in the C it generates and links
   libkelvin. It declares no libc functions, so it never conflicts with
   prototypes a Kelvin program writes by hand.

     print(v, ...)    prints each value according to its type
     println(v, ...)  the same, followed by a newline; println() prints
                      just a newline

   Integers print in decimal (including 128-bit ones), floats in the
   shortest form that reads back to the same value, bool as true/false,
   byte pointers (u8^, string literals) as strings and other pointers as
   addresses. Up to 16 values per call. */
#ifndef KELVIN_PRELUDE_H
#define KELVIN_PRELUDE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

void kv_print_char(char v);
void kv_print_i64(long long v);
void kv_print_u64(unsigned long long v);
void kv_print_f32(float v);
void kv_print_f64(double v);
void kv_print_f80(long double v);
void kv_print_bool(bool v);
void kv_print_str(const char *v);
void kv_print_ptr(const void *v);
void kv_print_newline(void);
#ifdef __SIZEOF_INT128__
void kv_print_i128(__int128 v);
void kv_print_u128(unsigned __int128 v);
#define KV_PRINT_INT128 __int128: kv_print_i128, unsigned __int128: kv_print_u128,
#else
#define KV_PRINT_INT128
#endif

/* C's own type names are listed rather than int64_t and friends, because
   int64_t is `long` on some platforms and `long long` on others, and a
   _Generic list may not name the same type twice. */
#define kv_print1(v) _Generic((v), \
    bool: kv_print_bool, \
    char: kv_print_char, \
    signed char: kv_print_i64, short: kv_print_i64, int: kv_print_i64, \
    long: kv_print_i64, long long: kv_print_i64, \
    unsigned char: kv_print_u64, unsigned short: kv_print_u64, unsigned: kv_print_u64, \
    unsigned long: kv_print_u64, unsigned long long: kv_print_u64, \
    KV_PRINT_INT128 \
    float: kv_print_f32, double: kv_print_f64, long double: kv_print_f80, \
    char *: kv_print_str, const char *: kv_print_str, \
    signed char *: kv_print_str, const signed char *: kv_print_str, \
    unsigned char *: kv_print_str, const unsigned char *: kv_print_str, \
    default: kv_print_ptr)(v)

#define KV_CAT_(a, b) a##b
#define KV_CAT(a, b) KV_CAT_(a, b)
/* __VA_OPT__ (C23, accepted by gcc and clang in C11 mode as well) lets
   print() and println() take no values */
#define KV_NARGS(...) KV_NARGS_(0 __VA_OPT__(,) __VA_ARGS__, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0)
#define KV_NARGS_(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, n, ...) n

#define kv_print_n0() ((void)0)
#define kv_print_n1(a) kv_print1(a)
#define kv_print_n2(a, ...) (kv_print1(a), kv_print_n1(__VA_ARGS__))
#define kv_print_n3(a, ...) (kv_print1(a), kv_print_n2(__VA_ARGS__))
#define kv_print_n4(a, ...) (kv_print1(a), kv_print_n3(__VA_ARGS__))
#define kv_print_n5(a, ...) (kv_print1(a), kv_print_n4(__VA_ARGS__))
#define kv_print_n6(a, ...) (kv_print1(a), kv_print_n5(__VA_ARGS__))
#define kv_print_n7(a, ...) (kv_print1(a), kv_print_n6(__VA_ARGS__))
#define kv_print_n8(a, ...) (kv_print1(a), kv_print_n7(__VA_ARGS__))
#define kv_print_n9(a, ...) (kv_print1(a), kv_print_n8(__VA_ARGS__))
#define kv_print_n10(a, ...) (kv_print1(a), kv_print_n9(__VA_ARGS__))
#define kv_print_n11(a, ...) (kv_print1(a), kv_print_n10(__VA_ARGS__))
#define kv_print_n12(a, ...) (kv_print1(a), kv_print_n11(__VA_ARGS__))
#define kv_print_n13(a, ...) (kv_print1(a), kv_print_n12(__VA_ARGS__))
#define kv_print_n14(a, ...) (kv_print1(a), kv_print_n13(__VA_ARGS__))
#define kv_print_n15(a, ...) (kv_print1(a), kv_print_n14(__VA_ARGS__))
#define kv_print_n16(a, ...) (kv_print1(a), kv_print_n15(__VA_ARGS__))

#define print(...) KV_CAT(kv_print_n, KV_NARGS(__VA_ARGS__))(__VA_ARGS__)
#define println(...) (print(__VA_ARGS__), kv_print_newline())

#endif
