// &f of a function's name is the function itself, a value of its type
// (documents/pointers.md): let g := &f calls as g(x), goes where a
// function goes, and is f; kc reads it so too (#536)
struct ops { f: (i64):i64 }
let twice(n:i64):i64 { n * 2 }
let add(a:i64):i64 { a + 1 }
let one():i64 { 1 }
let hello() { println("hi") }
let apply(f:(i64):i64, n:i64):i64 { f(n) }
let pick(up:bool):(i64):i64 { up ? &add : &twice }
let main():int32 {
    let g := &one
    let t := &twice
    let typed:(i64):i64 := &twice
    var v := &twice
    v := &add
    let o:ops = {&twice}
    let h := &hello
    var fs = $[&twice, twice]
    fs += &add
    h()
    println(g(), " ", t(4), " ", typed(4), " ", v(7), " ", o.f(8), " ", apply(&twice, 5), " ", apply(t, 9))
    println(t.typename, " ", (&twice).typename, " ", t == &twice, " ", t == twice, " ", fs[0](3), " ", fs[2](3), " ", pick(true)(10), " ", pick(false)(10))
    return 0
}
// out: hi
// out: 1 8 8 8 16 10 18
// out: (i64):i64 (i64):i64 true true 6 4 11 20
