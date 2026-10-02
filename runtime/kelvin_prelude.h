/* kelvin_prelude.h - the Kelvin prelude, available to every Kelvin program

   kelvinc includes this header in the C it generates and links
   libkelvin. It declares no libc functions, so it never conflicts with
   prototypes a Kelvin program writes by hand.

     print(v, ...)    prints each value according to its type
     println(v, ...)  the same, followed by a newline; println() prints
                      just a newline
     v.cstr           the text of a value, as cstr (u8^) on the stack
     v.dec, v.hex     the text of a number (and v.oct, v.bin for integers)

   print: integers print in decimal (including 128-bit ones), floats in
   the shortest form that reads back to the same value, bool as
   true/false, byte pointers (u8^, string literals) as strings and other
   pointers as addresses. Up to 16 values per call. */
#ifndef KELVIN_PRELUDE_H
#define KELVIN_PRELUDE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* ---------- x.cstr (#22) ---------- */

/* The text of a value, written into `buf` (a buffer on the caller's
   stack that kelvinc declares at the top of the enclosing block) and
   returned as u8^. Numbers are plain decimal ("42", "-7"), floats are
   lossless (%.9g for f32, %.17g for f64) and a NaN is "nan", bool is
   true/false, other pointers are addresses ("0x1f2e"), complex numbers
   are re+imi. A string (u8^) is its own text: s.cstr is s itself, and
   stays const if s is.
   A Kelvin struct's text, {x: 3, y: 4}, is written by a function kelvinc
   derives for it. A buffer for one value holds KV_CSTR_SCALAR bytes. */
#define KV_CSTR_SCALAR 64
uint8_t *kv_cstr_bool(bool v, uint8_t *buf);
uint8_t *kv_cstr_char(char v, uint8_t *buf);
uint8_t *kv_cstr_i64(long long v, uint8_t *buf);
uint8_t *kv_cstr_u64(unsigned long long v, uint8_t *buf);
uint8_t *kv_cstr_f32(float v, uint8_t *buf);
uint8_t *kv_cstr_f64(double v, uint8_t *buf);
uint8_t *kv_cstr_f80(long double v, uint8_t *buf);
uint8_t *kv_cstr_cf(float _Complex v, uint8_t *buf);
uint8_t *kv_cstr_cd(double _Complex v, uint8_t *buf);
uint8_t *kv_cstr_cld(long double _Complex v, uint8_t *buf);
uint8_t *kv_cstr_str(const char *v, uint8_t *buf);
const uint8_t *kv_cstr_cstr(const char *v, uint8_t *buf);
uint8_t *kv_cstr_ptr(const volatile void *v, uint8_t *buf);
#ifdef __SIZEOF_INT128__
uint8_t *kv_cstr_i128(__int128 v, uint8_t *buf);
uint8_t *kv_cstr_u128(unsigned __int128 v, uint8_t *buf);
#define KV_INT128_cstr __int128: kv_cstr_i128, unsigned __int128: kv_cstr_u128,
#else
#define KV_INT128_cstr
#endif

/* kelvinc turns `v.cstr` into
   _Generic((v), KV_PROPERTY_cstr <Kelvin structs> default: kv_cstr_ptr)(v, buf).
   C's own type names are listed rather than int64_t and friends, because
   int64_t is `long` on some platforms and `long long` on others, and a
   _Generic list may not name the same type twice. */
#define KV_PROPERTY_cstr \
    bool: kv_cstr_bool, char: kv_cstr_char, \
    signed char: kv_cstr_i64, short: kv_cstr_i64, int: kv_cstr_i64, \
    long: kv_cstr_i64, long long: kv_cstr_i64, \
    unsigned char: kv_cstr_u64, unsigned short: kv_cstr_u64, unsigned: kv_cstr_u64, \
    unsigned long: kv_cstr_u64, unsigned long long: kv_cstr_u64, \
    KV_INT128_cstr \
    float: kv_cstr_f32, double: kv_cstr_f64, long double: kv_cstr_f80, \
    float _Complex: kv_cstr_cf, double _Complex: kv_cstr_cd, \
    long double _Complex: kv_cstr_cld, \
    char *: kv_cstr_str, const char *: kv_cstr_cstr, \
    signed char *: kv_cstr_str, const signed char *: kv_cstr_cstr, \
    unsigned char *: kv_cstr_str, const unsigned char *: kv_cstr_cstr,

/* Selected for a Kelvin struct where kelvinc could not see the value's
   type, as in (c ? p : q).cstr, and so could not size the buffer for it;
   any call is a C type error that names this function. Assign the value
   to a variable first. */
struct kv_cstr_unseen_struct { char unused; };
uint8_t *kv_cstr_unseen_struct(struct kv_cstr_unseen_struct, uint8_t *);

/* For the derived text of structs: each writes at p and returns the end.
   A string inside a struct shows at most KV_CSTR_STR bytes; a longer one
   is cut and ends in "...". */
#define KV_CSTR_STR 60
uint8_t *kv_cstr_end(uint8_t *s);
uint8_t *kv_cstr_put(uint8_t *p, const char *text);
uint8_t *kv_cstr_put_str(uint8_t *p, const char *s);
uint8_t *kv_cstr_put_text(uint8_t *p, const void *s);
uint8_t *kv_cstr_put_address(uint8_t *p, const volatile void *v);

/* A pointer member whose type kelvinc cannot tell is text, such as
   xmlChar^ or uint8_t^: byte strings are text, other pointers addresses */
#define kv_cstr_put_pointer(p, lv) _Generic((lv), \
    char *: kv_cstr_put_text, const char *: kv_cstr_put_text, \
    signed char *: kv_cstr_put_text, const signed char *: kv_cstr_put_text, \
    unsigned char *: kv_cstr_put_text, const unsigned char *: kv_cstr_put_text, \
    default: kv_cstr_put_address)(p, lv)

/* ---------- properties: x.dec, x.hex, x.oct, x.bin (#21) ---------- */

/* The text of a number, written into `buf` (a buffer on the caller's
   stack that kelvinc sizes for the longest text) and returned as u8^. Signed
   integers always carry a sign ("+42", "-0x2a"), which tells them from
   unsigned ones ("42", "0x2a"). Prefixes are 0x, 0o and 0b. f32/f64 have
   .dec (%.17g style) and .hex (%a), always signed. */
uint8_t *kv_dec_signed(long long v, uint8_t *buf);
uint8_t *kv_dec_unsigned(unsigned long long v, uint8_t *buf);
uint8_t *kv_dec_char(char v, uint8_t *buf);
uint8_t *kv_dec_f32(float v, uint8_t *buf);
uint8_t *kv_dec_f64(double v, uint8_t *buf);
uint8_t *kv_hex_signed(long long v, uint8_t *buf);
uint8_t *kv_hex_unsigned(unsigned long long v, uint8_t *buf);
uint8_t *kv_hex_char(char v, uint8_t *buf);
uint8_t *kv_hex_f32(float v, uint8_t *buf);
uint8_t *kv_hex_f64(double v, uint8_t *buf);
uint8_t *kv_oct_signed(long long v, uint8_t *buf);
uint8_t *kv_oct_unsigned(unsigned long long v, uint8_t *buf);
uint8_t *kv_oct_char(char v, uint8_t *buf);
uint8_t *kv_bin_signed(long long v, uint8_t *buf);
uint8_t *kv_bin_unsigned(unsigned long long v, uint8_t *buf);
uint8_t *kv_bin_char(char v, uint8_t *buf);
#ifdef __SIZEOF_INT128__
uint8_t *kv_dec_i128(__int128 v, uint8_t *buf);
uint8_t *kv_dec_u128(unsigned __int128 v, uint8_t *buf);
uint8_t *kv_hex_i128(__int128 v, uint8_t *buf);
uint8_t *kv_hex_u128(unsigned __int128 v, uint8_t *buf);
uint8_t *kv_oct_i128(__int128 v, uint8_t *buf);
uint8_t *kv_oct_u128(unsigned __int128 v, uint8_t *buf);
uint8_t *kv_bin_i128(__int128 v, uint8_t *buf);
uint8_t *kv_bin_u128(unsigned __int128 v, uint8_t *buf);
#define KV_INT128_PROPERTY(p) __int128: kv_##p##_i128, unsigned __int128: kv_##p##_u128,
#else
#define KV_INT128_PROPERTY(p)
#endif

#define KV_INT_PROPERTY(p) \
    char: kv_##p##_char, \
    signed char: kv_##p##_signed, short: kv_##p##_signed, int: kv_##p##_signed, \
    long: kv_##p##_signed, long long: kv_##p##_signed, \
    unsigned char: kv_##p##_unsigned, unsigned short: kv_##p##_unsigned, unsigned: kv_##p##_unsigned, \
    unsigned long: kv_##p##_unsigned, unsigned long long: kv_##p##_unsigned, \
    KV_INT128_PROPERTY(p)

#define KV_PROPERTY_dec KV_INT_PROPERTY(dec) float: kv_dec_f32, double: kv_dec_f64,
#define KV_PROPERTY_hex KV_INT_PROPERTY(hex) float: kv_hex_f32, double: kv_hex_f64,
#define KV_PROPERTY_oct KV_INT_PROPERTY(oct)
#define KV_PROPERTY_bin KV_INT_PROPERTY(bin)

/* Selected when a type has no such property. Its parameter is a struct
   that nothing else has, taken by value, so any call is a C type error
   that names this function, also with a pointer, which a pointer
   parameter would only warn about. */
struct kv_no_such_property { char unused; };
uint8_t *kv_no_such_property(struct kv_no_such_property, uint8_t *);

/* Conditions are bool (#23). Where kelvinc cannot see a condition's
   type, it emits _Generic((c), bool: kv_bool, default:
   kv_condition_is_not_bool)(c): a bool passes through, and anything else
   is a C type error that names kv_condition_is_not_bool. */
static inline bool kv_bool(bool b) { return b; }
struct kv_condition_is_not_bool { char unused; };
bool kv_condition_is_not_bool(struct kv_condition_is_not_bool);

/* Selected when a type has no such method; any call is a C type error
   that names this function, as above. */
struct kv_no_such_method { char unused; };
void kv_no_such_method(struct kv_no_such_method);

/* The text of a struct member whose type kelvinc cannot see, such as a
   C typedef: numbers, bool and complex numbers as .cstr gives them, byte
   strings as text, a char array (typedef char name_t[16]) as the text
   in it, void * as an address, anything else "{...}" (a struct, an array
   of other things, a pointer to anything else). At most
   KV_CSTR_SCALAR - 1 bytes. _Generic sees an array as a pointer, so
   the type of &(lv) tells a char array from a char *. */
enum {
    KV_K_OPAQUE, KV_K_BOOL, KV_K_CHAR, KV_K_SCHAR, KV_K_UCHAR, KV_K_SHORT, KV_K_USHORT, KV_K_INT,
    KV_K_UINT, KV_K_LONG, KV_K_ULONG, KV_K_LLONG, KV_K_ULLONG, KV_K_I128, KV_K_U128, KV_K_FLOAT,
    KV_K_DOUBLE, KV_K_LDOUBLE, KV_K_STR, KV_K_CHARS, KV_K_PTR, KV_K_CF, KV_K_CD, KV_K_CLD,
};
uint8_t *kv_cstr_kind(const void *p, int kind, size_t size, uint8_t *buf);
#ifdef __SIZEOF_INT128__
#define KV_INT128_KIND __int128: KV_K_I128, unsigned __int128: KV_K_U128,
#else
#define KV_INT128_KIND
#endif
#define kv_cstr_any(lv, buf) kv_cstr_kind((const void *)&(lv), _Generic((lv), \
    bool: KV_K_BOOL, char: KV_K_CHAR, signed char: KV_K_SCHAR, unsigned char: KV_K_UCHAR, \
    short: KV_K_SHORT, unsigned short: KV_K_USHORT, int: KV_K_INT, unsigned: KV_K_UINT, \
    long: KV_K_LONG, unsigned long: KV_K_ULONG, long long: KV_K_LLONG, \
    unsigned long long: KV_K_ULLONG, KV_INT128_KIND \
    float: KV_K_FLOAT, double: KV_K_DOUBLE, long double: KV_K_LDOUBLE, \
    float _Complex: KV_K_CF, double _Complex: KV_K_CD, long double _Complex: KV_K_CLD, \
    char *: _Generic(&(lv), char (*)[sizeof(lv)]: KV_K_CHARS, default: KV_K_STR), \
    const char *: _Generic(&(lv), const char (*)[sizeof(lv)]: KV_K_CHARS, default: KV_K_STR), \
    signed char *: _Generic(&(lv), signed char (*)[sizeof(lv)]: KV_K_OPAQUE, default: KV_K_STR), \
    const signed char *: _Generic(&(lv), const signed char (*)[sizeof(lv)]: KV_K_OPAQUE, default: KV_K_STR), \
    unsigned char *: _Generic(&(lv), unsigned char (*)[sizeof(lv)]: KV_K_OPAQUE, default: KV_K_STR), \
    const unsigned char *: _Generic(&(lv), const unsigned char (*)[sizeof(lv)]: KV_K_OPAQUE, default: KV_K_STR), \
    void *: KV_K_PTR, const void *: KV_K_PTR, \
    default: KV_K_OPAQUE), sizeof(lv), buf)

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
