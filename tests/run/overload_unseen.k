// overloading (#41) where only C sees an argument's type, as for what a C
// function gives: C's _Generic chooses, by the C type of a struct, a
// pointer, an enum or a C typedef, and by the Kelvin type of a number, so
// that C's long and long long are both i64. A number or a pointer of
// another type goes to the one overload that takes one, and a number no
// overload takes to C's own function of the name.
#import <math.h> as C
#import <stdio.h> as C
#import <stdlib.h> as C
#import <string.h> as C

struct vec { x: f64; y: f64 }

kind(n:i64):cstr { "i64" }
kind(n:i32):cstr { "i32" }
kind(x:f64):cstr { "f64" }
kind(x:f32):cstr { "f32" }
kind(n:u8):cstr { "u8" }
kind(s:const u8^):cstr { "text" }
kind(v:vec):cstr { "vec" }

len(s:const u8^):i64 { i64(strlen(s)) }
len(n:i64):i64 { n }

out(f:FILE^, n:i64) { fprintf(f, "%s\n", n.cstr) }
out(f:FILE^, s:const u8^) { fprintf(f, "%s\n", s) }

release(p:any^):cstr {
    free(p)
    return "freed"
}
release(n:i64):cstr { "number" }

measure(n:i64):i64 { n }
measure(n:size_t):i64 { i64(n) * 10 }

// C's sqrt, declared so that a number only C sees reaches it
sqrt(x:f64):f64
sqrt(v:vec):f64 { hypot(v.x, v.y) }

// C's abs and hypot, which the program calls, take what no overload does,
// and their results have C's types
struct vec2 { x: i64; y: i64 }
abs(v:vec):i64 { i64(hypot(v.x, v.y)) }
abs(w:vec2):i64 { w.x * w.x + w.y * w.y }
hypot(v:vec, w:vec):f64 { hypot(v.x - w.x, v.y - w.y) }
hypot(v:vec, k:f64):f64 { hypot(v.x, v.y) * k }
half(n:i64):i64 { n / 2 }
half(x:f64):f64 { x / 2.0 }

// the overload kelvinc sees fits best, C choosing where only it sees
pair(a:i64, b:size_t):cstr { "i64" }
pair(a:f64, b:size_t):cstr { "f64" }
total(n:i64, ...):cstr { "va" }
total(n:i64, x:f64):cstr { "f64" }
enum sign { NEGATIVE = -1, ZERO, POSITIVE }
describe(s:sign):cstr { "sign" }
describe(n:i32):cstr { "i32" }

main():i32 {
    println(kind(strtol("1", nullptr, 10)), " ", kind(strtoll("1", nullptr, 10)), " ", kind(atan2(1.0, 1.0)), " ",
            kind(floorf(1.5:f32)), " ", kind(strchr("abc", 'b')[0]), " ", kind(strchr("abc", 'b')))
    println(len(strchr("hello", 'l')), " ", len(strtol("7", nullptr, 10)), " ", len(strtoll("8", nullptr, 10)), " ",
            release(malloc(8)), " ", release(labs(-3)), " ", measure(strlen("abc")), " ", measure(4))
    out(stdout, 5)
    out(stdout, strchr("six", 's'))
    // sqrt of a number is C's, whose own value only C sees
    println(sqrt(fabs(-9.0)), " ", sqrt((vec){3.0, 4.0}))
    println(abs(-2), " ", kind(abs(atoi("-5"))), " ", kind(half(atof("3"))), " ", hypot(3.0, 4.0), " ",
            hypot(fabs(-3.0), fabs(4.0)), " ", hypot((vec){3.0, 4.0}, 0.5))
    println(pair(3, strlen("ab")), " ", total(1, strchr("abc", 'b')), " ", total(1, atof("2")), " ", describe(abs(-5)),
            " ", describe(POSITIVE))
    return 0
}
// out: i64 i64 f64 f32 u8 text
// out: 3 7 8 freed number 30 4
// out: 5
// out: six
// out: 3.0 5.0
// out: 2 i32 f64 5.0 5.0 2.5
// out: i64 va f64 i32 sign
// c: __builtin_choose_expr(KV_NUMBER(_kv_self0) == KV_N_I64, kind__i64
// c: __builtin_choose_expr(KV_POINTER(_kv_self6), len__const_u8p
// c: _Generic((_kv_self11), size_t: measure__size_t, default:
// c: _Generic((_kv_self14), struct vec: sqrt__vec, default: __builtin_choose_expr(KV_NUMBER(_kv_self14) == KV_N_F64, sqrt,
