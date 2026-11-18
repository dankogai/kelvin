// An operator of the prelude's own types is the prelude's alone (#606),
// and a program's of other types stands beside it: of one of the
// prelude's types and one of its own, and of a type of its own that has
// the name of one of the prelude's (#600), which is another type
struct P { x: f64 }
struct BigInt { n: i64 }
let +(a:c64, b:P):c64 { c64(a.real + b.x, a.imag) }
let +(a:BigInt, b:BigInt):BigInt { (BigInt){a.n + b.n + 100} }
let main():int32 {
    let p:P = {1.0}
    let mine:BigInt = {1}
    println(c64(1.0, 2.0) + p, " ", c64(1.0, 2.0) + c64(1.0, 1.0), " ", mine + mine, " ", 1n + 1n)
    return 0
}
// out: (2.0+2.0.i) (2.0+3.0.i) {n: 102} 2n
