// overloading (#41): functions of one name with different parameter
// types, chosen by the arguments' types where kelvinc sees them. A
// literal has its type, also negated (#24), a comparison is a bool, an
// enumerator its enum, and arithmetic the type C gives it. C's function
// of a name is called only where no Kelvin function has it (#223): beside
// one, it is declared as an overload, and keeps its C name.
#import <math.h> as C
#import <stdlib.h> as C
#import <string.h> as C

struct vec { x: float64; y: float64 }
struct node { v: int64; next: node^ }
enum color { RED, GREEN, BLUE }

let twice(n:int64):int64 { n * 2 }
let twice(x:float64):float64 { x * 2.0 }
let twice(s:const uint8^):int64 { int64(strlen(s)) * 2 }
let twice(v:vec):vec { (vec){v.x * 2.0, v.y * 2.0} }

// a prototype and its definition are one overload, also with a const
// on a parameter itself
let scale(v:vec, k:float64):vec
let scale(v:const vec, k:float64):vec { (vec){v.x * k, v.y * k} }
let scale(k:float64, v:vec):vec { scale(v, k) }

// recursion through arithmetic, which has the type C gives it
let fact(n:int64):int64 { n <= 1 ? 1 : n * fact(n - 1) }
let fact(x:float64):float64 { x <= 1.0 ? 1.0 : x * fact(x - 1.0) }

let pick(b:bool):int64 { 1 }
let pick(n:int64):int64 { 2 }
let count(p:node^):int64 { p == nullptr ? 0 : 1 + count(p^.next) }
let count(n:int64):int64 { n }
let show(c:color):int64 { 100 + int64(c) }
let show(n:int64):int64 { n }

// the overload every argument kelvinc sees fits best
let mix(a:int64, b:float64):int64 { 1 }
let mix(a:float64, b:float64):int64 { 2 }

// a pointer may gain const, never lose it
let put(p:uint8^):int64 { 1 }
let put(p:const any^):int64 { 2 }

// function types and variadic functions have names of their own in C, and an
// array parameter is a pointer
let run(a:(int64), b:(int64):int64):int64 { b(1) }
let run(g:(int64, (int64):int64)):int64 { 2 }
let total(n:int64, ...):int64 { n }
let total(s:const uint8^):int64 { -1 }
let first(a:[int64](3)):int64 { a[0] }
let first(x:float64):int64 { 0 }

// C's sqrt and fabs, declared, take numbers (#223)
let sqrt(x:float64):float64
let fabs(x:float64):float64
let sqrt(v:vec):float64 { sqrt(v.x * v.x + v.y * v.y) }
let fabs(v:vec):vec { (vec){fabs(v.x), fabs(v.y)} }

// C's abs, declared by hand, keeps its name beside an overload, and so does
// C's sin, called before Kelvin overloads it
let abs(n:int32):int32
let abs(v:vec):float64 { sqrt(v) }
let half_sin(x:float64):float64 { sin(x) / 2.0 }
let sin(x:float64):float64
let sin(v:vec):vec { (vec){sin(v.x), sin(v.y)} }

// anonymous functions take the parameter types the overloads agree on
let each(n:int64, f:(int64):int64):int64 { f(n) }
let each(s:const uint8^, f:(int64):int64):int64 { f(int64(strlen(s))) }
let zero():int64 { 0 }
let zero(n:int64):int64 { n - n }

// an overloaded name as a value: the overload of the type wanted, and
// an overloaded function given one: the one taking that type
let apply(f:(int64):int64, n:int64):int64 { f(n) }
let apply(f:(float64):float64, x:float64):float64 { f(x) }
let halver():(float64):float64 { twice }
let doubler():(int64):int64 {
    return twice
}
let nothing(n:int64) { }
let once(n:int64):int64 { n }

let main():int32 {
    let v:vec = {3.0, -4.0}
    let small:int32 = 21
    let quarter:float32 = 0.25
    let name:uint8^ := "abc" as uint8^
    let n:int64 = 3
    let x:float64 = 1.5
    println(twice(4), " ", twice(1.5), " ", twice("abc"), " ", twice(name), " ", twice(v).y)
    println(twice(-3), " ", twice(-x), " ", twice(n * n), " ", twice(x * 2.0 - 1.0), " ", twice(n > 2 ? n : -n))
    println(fact(5), " ", fact(4.0), " ", pick(true), " ", pick(n < 2), " ", pick(!(n > 3)), " ", pick(-4))
    var tail:node = {2, nullptr}
    var head:node = {1, &tail}
    println(count(&head), " ", count(nullptr), " ", count(7), " ", show(GREEN), " ", show(BLUE as int64))
    // a number of another type converts, as C converts it, to the one
    // overload that takes it
    println(scale(v, small).x, " ", scale(quarter, v).y, " ", twice(small as int64), " ", mix(n, 2.0), " ", mix(x, 2.0))
    let cs:const uint8^ := "hello"
    var three:[int64](3) = [7, 8, 9]
    println(put(name), " ", put(cs), " ", run({ (k:int64) in nothing(k) }, once), " ", total(1, 2, 3), " ", first(three))
    println(sqrt(v), " ", sqrt(16.0), " ", fabs(v).y, " ", fabs(-2.5), " ", scale(2.0, v).x, " ", (once)(5))

    // function values
    let f:(int64):int64 := twice
    var g:(float64):float64 := halver()
    let root:(float64):float64 := sqrt
    println(f(5), " ", g(0.75), " ", doubler()(4), " ", apply(twice, 7), " ", apply(twice, 0.25), " ", root(16.0))
    g := twice
    println(g(0.5), " ", apply({ (y:float64):float64 in y * 3.0 }, x), " ", mix(n, 2), " ", each(4) { $0 + 1 }, " ",
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
