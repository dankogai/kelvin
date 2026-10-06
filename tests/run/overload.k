// overloading (#41): functions of one name with different parameter
// types, chosen by the arguments' types where kelvinc sees them. A
// literal has its type, also negated (#24), a comparison is a bool, an
// enumerator its enum, and arithmetic the type C gives it. A Kelvin
// function of a C function's name overloads it, and C's own takes the
// arguments no overload does.
#import <math.h> as C
#import <stdlib.h> as C
#import <string.h> as C

struct vec { x: f64; y: f64 }
struct node { v: i64; next: node^ }
enum color { RED, GREEN, BLUE }

let twice(n:i64):i64 { n * 2 }
let twice(x:f64):f64 { x * 2.0 }
let twice(s:const u8^):i64 { i64(strlen(s)) * 2 }
let twice(v:vec):vec { (vec){v.x * 2.0, v.y * 2.0} }

// a prototype and its definition are one overload, also with a const
// on a parameter itself
let scale(v:vec, k:f64):vec
let scale(v:const vec, k:f64):vec { (vec){v.x * k, v.y * k} }
let scale(k:f64, v:vec):vec { scale(v, k) }

// recursion through arithmetic, which has the type C gives it
let fact(n:i64):i64 { n <= 1 ? 1 : n * fact(n - 1) }
let fact(x:f64):f64 { x <= 1.0 ? 1.0 : x * fact(x - 1.0) }

let pick(b:bool):i64 { 1 }
let pick(n:i64):i64 { 2 }
let count(p:node^):i64 { p == nullptr ? 0 : 1 + count(p^.next) }
let count(n:i64):i64 { n }
let show(c:color):i64 { 100 + i64(c) }
let show(n:i64):i64 { n }

// the overload every argument kelvinc sees fits best
let mix(a:i64, b:f64):i64 { 1 }
let mix(a:f64, b:f64):i64 { 2 }

// a pointer may gain const, never lose it
let put(p:u8^):i64 { 1 }
let put(p:const any^):i64 { 2 }

// function types and variadic functions have names of their own in C, and an
// array parameter is a pointer
let run(a:(i64), b:(i64):i64):i64 { b(1) }
let run(g:(i64, (i64):i64)):i64 { 2 }
let total(n:i64, ...):i64 { n }
let total(s:const u8^):i64 { -1 }
let first(a:[i64](3)):i64 { a[0] }
let first(x:f64):i64 { 0 }

// C's sqrt and fabs still take numbers
let sqrt(v:vec):f64 { sqrt(v.x * v.x + v.y * v.y) }
let fabs(v:vec):vec { (vec){fabs(v.x), fabs(v.y)} }

// C's abs, declared by hand, keeps its name beside an overload, and so does
// C's sin, called before Kelvin overloads it
let abs(n:i32):i32
let abs(v:vec):f64 { sqrt(v) }
let half_sin(x:f64):f64 { sin(x) / 2.0 }
let sin(v:vec):vec { (vec){sin(v.x), sin(v.y)} }

// anonymous functions take the parameter types the overloads agree on
let each(n:i64, f:(i64):i64):i64 { f(n) }
let each(s:const u8^, f:(i64):i64):i64 { f(i64(strlen(s))) }
let zero():i64 { 0 }
let zero(n:i64):i64 { n - n }

// an overloaded name as a value: the overload of the type wanted, and
// an overloaded function given one: the one taking that type
let apply(f:(i64):i64, n:i64):i64 { f(n) }
let apply(f:(f64):f64, x:f64):f64 { f(x) }
let halver():(f64):f64 { twice }
let doubler():(i64):i64 {
    return twice
}
let nothing(n:i64) { }
let once(n:i64):i64 { n }

let main():i32 {
    let v:vec = {3.0, -4.0}
    let small:i32 = 21
    let quarter:f32 = 0.25
    let name:u8^ := "abc" as u8^
    let n:i64 = 3
    let x:f64 = 1.5
    println(twice(4), " ", twice(1.5), " ", twice("abc"), " ", twice(name), " ", twice(v).y)
    println(twice(-3), " ", twice(-x), " ", twice(n * n), " ", twice(x * 2.0 - 1.0), " ", twice(n > 2 ? n : -n))
    println(fact(5), " ", fact(4.0), " ", pick(true), " ", pick(n < 2), " ", pick(!(n > 3)), " ", pick(-4))
    var tail:node = {2, nullptr}
    var head:node = {1, &tail}
    println(count(&head), " ", count(nullptr), " ", count(7), " ", show(GREEN), " ", show(BLUE as i64))
    // a number of another type converts, as C converts it, to the one
    // overload that takes it
    println(scale(v, small).x, " ", scale(quarter, v).y, " ", twice(small as i64), " ", mix(n, 2.0), " ", mix(x, 2.0))
    let cs:const u8^ := "hello"
    var three:[i64](3) = [7, 8, 9]
    println(put(name), " ", put(cs), " ", run({ (k:i64) in nothing(k) }, once), " ", total(1, 2, 3), " ", first(three))
    println(sqrt(v), " ", sqrt(16.0), " ", fabs(v).y, " ", fabs(-2.5), " ", scale(2.0, v).x, " ", (once)(5))

    // function values
    let f:(i64):i64 := twice
    var g:(f64):f64 := halver()
    let root:(f64):f64 := sqrt
    println(f(5), " ", g(0.75), " ", doubler()(4), " ", apply(twice, 7), " ", apply(twice, 0.25), " ", root(16.0))
    g := twice
    println(g(0.5), " ", apply({ (y:f64):f64 in y * 3.0 }, x), " ", mix(n, 2), " ", each(4) { $0 + 1 }, " ",
            each("abc") { $0 * 10 })
    println(abs(-3), " ", abs(v), " ", half_sin(0.0), " ", zero(), " ", zero(7))
    return 0
}
// out: 8 3.0 6 6 -8.0
// out: -6 -3.0 18 4.0 6
// out: 120 24.0 1 1 1 2
// out: 2 0 7 101 2
// out: 63.0 -1.0 42 1 2
// out: 1 2 1 1 7
// out: 5.0 4.0 4.0 2.5 6.0 5
// out: 10 1.5 8 14 0.5 4.0
// out: 1.0 4.5 1 5 30
// out: 3 5.0 0.0 0 0
// c: int64_t twice__i64(const int64_t n)
// c: double twice__f64(const double x)
// c: twice__i64(-3), " ", twice__f64(-x), " ", twice__i64(n * n), " ", twice__f64(x * 2.0 - 1.0), " ", twice__i64(n > 2 ? n : -n)
// c: pick__bool((bool)true), " ", pick__bool(((bool)(n < 2))), " ", pick__bool(((bool)!(n > 3))), " ", pick__i64(-4)
// c: count__nodep(((void *)0)), " ", count__i64(7), " ", show__color(GREEN)
// c: mix__i64__f64(n, 2)
// c: int32_t abs(int32_t n);
// c: int64_t zero__void(void)
// c: struct vec sin__vec(const struct vec v)
// c: int64_t twice__const_u8p(const uint8_t *const s)
// c: double sqrt__vec(const struct vec v)
// c: int64_t run__Fi64E__Fi64Ei64(
// c: int64_t run__Fi64_Fi64Ei64E(
// c: int64_t total__i64__va(const int64_t n, ...)
// c: int64_t first__i64p(int64_t *const a)
// c: ((once))(5)
// c: double (*const root)(double) = sqrt;
