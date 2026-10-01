/* kelvin_prelude.h - the Kelvin prelude, available to every Kelvin program

   kelvinc includes this header in the C it generates and links
   libkelvin. It declares no libc functions, so it never conflicts with
   prototypes a Kelvin program writes by hand.

     print(v, ...)    prints each value according to its type
     println(v, ...)  the same, followed by a newline; println() prints
                      just a newline
     String           a string value of up to 255 bytes, stored inline
     v.toString()     every type's text form, as a String
     v.fmt(format)    printf-style formatting of one value, as a String

   print: integers print in decimal (including 128-bit ones), floats in
   the shortest form that reads back to the same value, bool as
   true/false, byte pointers (u8^, string literals) as strings and other
   pointers as addresses. Up to 16 values per call. */
#ifndef KELVIN_PRELUDE_H
#define KELVIN_PRELUDE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* ---------- String ---------- */

/* A String holds its text inline, so it is a plain value: it can be
   returned, copied and passed without allocation or freeing. Longer
   text is truncated. Its bytes are u8, NUL-terminated. */
#define KV_STRING_SIZE 256

typedef struct kv_String {
    unsigned char bytes[KV_STRING_SIZE];
} kv_String;

void kv_string_append(kv_String *s, const char *text);

/* ---------- toString ---------- */

kv_String kv_toString_bool(bool v);
kv_String kv_toString_char(char v);
kv_String kv_toString_i64(long long v);
kv_String kv_toString_u64(unsigned long long v);
kv_String kv_toString_f32(float v);   /* "%.9g": lossless for f32 */
kv_String kv_toString_f64(double v);  /* "%.17g": lossless for f64 */
kv_String kv_toString_f80(long double v);
kv_String kv_toString_str(const char *v);
kv_String kv_toString_ptr(const void *v);
kv_String kv_toString_String(kv_String v);
kv_String kv_toString_cf(float _Complex v);   /* re+imi */
kv_String kv_toString_cd(double _Complex v);
kv_String kv_toString_cld(long double _Complex v);

/* ---------- fmt ---------- */

/* fmt takes a printf format with exactly one conversion (and any %%):
   flags, width and precision (each at most 4096), and one of
   d i o u x X c f F e E g G a A s p. No length modifiers: the value's
   own type decides. The value is converted to the conversion's kind, so
   42.fmt("%.2f") is "42.00" and an unsigned conversion of a negative
   value shows its bits in the value's own width. Flags C leaves
   undefined for a conversion are ignored. Anything else gives
   "<invalid format>". */
kv_String kv_fmt_bool(bool v, const char *format);
kv_String kv_fmt_char(char v, const char *format);
/* one per signed width, so %x of a negative i32 is 8 hex digits */
kv_String kv_fmt_i8(signed char v, const char *format);
kv_String kv_fmt_i16(short v, const char *format);
kv_String kv_fmt_i32(int v, const char *format);
kv_String kv_fmt_long(long v, const char *format);
kv_String kv_fmt_i64(long long v, const char *format);
kv_String kv_fmt_u64(unsigned long long v, const char *format);
kv_String kv_fmt_f32(float v, const char *format);
kv_String kv_fmt_f64(double v, const char *format);
kv_String kv_fmt_f80(long double v, const char *format);
kv_String kv_fmt_str(const char *v, const char *format);
kv_String kv_fmt_ptr(const void *v, const char *format);
kv_String kv_fmt_String(kv_String v, const char *format);
kv_String kv_fmt_cf(float _Complex v, const char *format); /* %s only */
kv_String kv_fmt_cd(double _Complex v, const char *format);
kv_String kv_fmt_cld(long double _Complex v, const char *format);

#ifdef __SIZEOF_INT128__
kv_String kv_toString_i128(__int128 v);
kv_String kv_toString_u128(unsigned __int128 v);
kv_String kv_fmt_i128(__int128 v, const char *format);
kv_String kv_fmt_u128(unsigned __int128 v, const char *format);
#define KV_INT128_toString __int128: kv_toString_i128, unsigned __int128: kv_toString_u128,
#define KV_INT128_fmt __int128: kv_fmt_i128, unsigned __int128: kv_fmt_u128,
#else
#define KV_INT128_toString
#define KV_INT128_fmt
#endif

/* Method dispatch: kelvinc turns `v.toString()` into
   _Generic((v), KV_METHOD_toString <user types> default: ...)(v).
   C's own type names are listed rather than int64_t and friends, because
   int64_t is `long` on some platforms and `long long` on others, and a
   _Generic list may not name the same type twice. */
#define KV_METHOD_toString \
    bool: kv_toString_bool, char: kv_toString_char, \
    signed char: kv_toString_i64, short: kv_toString_i64, int: kv_toString_i64, \
    long: kv_toString_i64, long long: kv_toString_i64, \
    unsigned char: kv_toString_u64, unsigned short: kv_toString_u64, unsigned: kv_toString_u64, \
    unsigned long: kv_toString_u64, unsigned long long: kv_toString_u64, \
    KV_INT128_toString \
    float: kv_toString_f32, double: kv_toString_f64, long double: kv_toString_f80, \
    float _Complex: kv_toString_cf, double _Complex: kv_toString_cd, \
    long double _Complex: kv_toString_cld, \
    char *: kv_toString_str, const char *: kv_toString_str, \
    signed char *: kv_toString_str, const signed char *: kv_toString_str, \
    unsigned char *: kv_toString_str, const unsigned char *: kv_toString_str, \
    kv_String: kv_toString_String,

#define KV_METHOD_fmt \
    bool: kv_fmt_bool, char: kv_fmt_char, \
    signed char: kv_fmt_i8, short: kv_fmt_i16, int: kv_fmt_i32, \
    long: kv_fmt_long, long long: kv_fmt_i64, \
    unsigned char: kv_fmt_u64, unsigned short: kv_fmt_u64, unsigned: kv_fmt_u64, \
    unsigned long: kv_fmt_u64, unsigned long long: kv_fmt_u64, \
    KV_INT128_fmt \
    float: kv_fmt_f32, double: kv_fmt_f64, long double: kv_fmt_f80, \
    float _Complex: kv_fmt_cf, double _Complex: kv_fmt_cd, long double _Complex: kv_fmt_cld, \
    char *: kv_fmt_str, const char *: kv_fmt_str, \
    signed char *: kv_fmt_str, const signed char *: kv_fmt_str, \
    unsigned char *: kv_fmt_str, const unsigned char *: kv_fmt_str, \
    kv_String: kv_fmt_String,

/* Selected when a type has no such method; calling it is a C type error
   that names this function. */
struct kv_no_such_method;
void kv_no_such_method(struct kv_no_such_method *);

/* toString of a value whose type kelvinc cannot see, such as a field of a
   C typedef type: scalars print as usual, anything else as "{...}". */
enum {
    KV_K_OPAQUE, KV_K_BOOL, KV_K_CHAR, KV_K_SCHAR, KV_K_UCHAR, KV_K_SHORT, KV_K_USHORT, KV_K_INT,
    KV_K_UINT, KV_K_LONG, KV_K_ULONG, KV_K_LLONG, KV_K_ULLONG, KV_K_I128, KV_K_U128, KV_K_FLOAT,
    KV_K_DOUBLE, KV_K_LDOUBLE, KV_K_STR, KV_K_CSTR, KV_K_STRING,
};
kv_String kv_toString_kind(const void *p, int kind);
#ifdef __SIZEOF_INT128__
#define KV_INT128_KIND __int128: KV_K_I128, unsigned __int128: KV_K_U128,
#else
#define KV_INT128_KIND
#endif
#define kv_toString_any(lv) kv_toString_kind((const void *)&(lv), _Generic((lv), \
    bool: KV_K_BOOL, char: KV_K_CHAR, signed char: KV_K_SCHAR, unsigned char: KV_K_UCHAR, \
    short: KV_K_SHORT, unsigned short: KV_K_USHORT, int: KV_K_INT, unsigned: KV_K_UINT, \
    long: KV_K_LONG, unsigned long: KV_K_ULONG, long long: KV_K_LLONG, \
    unsigned long long: KV_K_ULLONG, KV_INT128_KIND \
    float: KV_K_FLOAT, double: KV_K_DOUBLE, long double: KV_K_LDOUBLE, \
    char *: KV_K_STR, const char *: KV_K_CSTR, kv_String: KV_K_STRING, default: KV_K_OPAQUE))

/* ---------- print ---------- */

void kv_print_char(char v);
void kv_print_i64(long long v);
void kv_print_u64(unsigned long long v);
void kv_print_f32(float v);
void kv_print_f64(double v);
void kv_print_f80(long double v);
void kv_print_bool(bool v);
void kv_print_str(const char *v);
void kv_print_ptr(const void *v);
void kv_print_String(kv_String v);
void kv_print_newline(void);
#ifdef __SIZEOF_INT128__
void kv_print_i128(__int128 v);
void kv_print_u128(unsigned __int128 v);
#define KV_PRINT_INT128 __int128: kv_print_i128, unsigned __int128: kv_print_u128,
#else
#define KV_PRINT_INT128
#endif

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
    kv_String: kv_print_String, \
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
