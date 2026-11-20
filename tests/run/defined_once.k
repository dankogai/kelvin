// what #646 leaves as it was: a prototype and its definition are one
// function, overloads differ in their parameter types, a function of a
// type's name makes one, and a block's own enum and struct are the
// block's
let twice(n:i64):i64
struct p { x:i64 }
let p(n:i64):p { return {n * 10} }
let p.g(a:i64):i64 { return a + .x }
let p.g(a:f64):i64 { return (a as i64) * 2 }
let twice(n:i64):i64 { return n * 2 }
let twice(x:f64):f64 { return x * 2.0 }
enum color { red, green }
let main():int32 {
    enum shade { red, dark }
    let q = p(4)
    println(twice(3), " ", twice(1.5), " ", q.g(1), " ", q.g(2.5), " ", green, " ", dark)
    return 0
}
// out: 6 3.0 41 4 1 1
