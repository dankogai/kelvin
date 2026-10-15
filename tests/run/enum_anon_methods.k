// methods and operators on a type with no tag (#121): a method names its
// receiver by the type's spelling, let enum{...}.name(), with self as any
// method's; an operator takes it by its spelling too; and an operator of
// an enum with values, named or not, is the program's when it defines one
enum { nothing; just: i64 }
let enum{nothing, just: i64}.orZero():i64 { .is(just) ? .just : 0 }
let enum{nothing, just: i64}.or(v:i64):i64 { .is(just) ? .just : v }
let enum{nothing, just: i64}.twice():i64 { .orZero() * 2 }      // one method calls another
let enum{nothing, just: i64}.cstr():cstr { `<${.orZero()}>` }  // its own text, as a struct's (#53)
let +(a:enum{nothing, just: i64}, b:enum{nothing, just: i64}):enum{nothing, just: i64} {
    if a.is(just) && b.is(just) { return {.just = a.just + b.just} }
    return {.nothing}
}
let <(a:enum{nothing, just: i64}, b:enum{nothing, just: i64}):bool { a.orZero() < b.orZero() }
enum maybe { none; some: i64 }                 // a named one: an operator of its own, and its == written
let -(a:maybe, b:maybe):maybe {
    if a.is(some) && b.is(some) { return {.some = a.some - b.some} }
    return {.none}
}
let ==(a:maybe, b:maybe):bool { a.is(some) == b.is(some) }       // only whether both hold a value
let {x: f64, y: f64}.norm2():f64 { .x * .x + .y * .y }   // a struct with no tag: the same form
let main():i32 {
    var a = just(3)
    var n = nothing
    println(a.orZero(), " ", n.orZero(), " ", n.or(-1), " ", a.twice())
    var s = a + just(4)
    var t = a + nothing
    println(s.cstr, " ", t.cstr, " ", a < s, " ", s < a, " ", `${a}`)
    var p = maybe.some(10) - maybe.some(4)
    var q = maybe.some(1) - maybe.none
    println(p.cstr, " ", q.cstr, " ", maybe.some(1) == maybe.some(2), " ", maybe.some(1) != maybe.none)
    var v:{x: f64, y: f64} = {3.0, 4.0}
    println(v.norm2())
    return 0
}
// out: 3 0 -1 6
// out: <7> <0> true false <3>
// out: some(6) none true true
// out: 25.0
// c: _kv_anon1__orZero(
