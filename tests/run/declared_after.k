// a type, an enum, a typealias and a global may be used before they are
// written, as a function may (#505) and as in Swift (#626): kelvinc moves
// each up to just before the first declaration that names it, after the
// ones it names, and declares two records that point at each other ahead
let main():int32 {
    var p:point = {3, 4}
    let c = green
    let n:count = 5
    println(norm2(&p), " ", c.typename, " ", c, " ", n, " ", limit, " ", origin.x)
    var a:left = {1, nowhere}
    var b:right = {2, &a}
    a.other := &b
    println(a.other^.n, " ", b.other^.n, " ", p.sum())
    return 0
}

let norm2(p:point^):i64 { p^.x * p^.x + p^.y * p^.y }

extend point {
    let sum():i64 { .x + .y }
}

struct point { x: i64; y: i64 }

enum color { red, green, blue }

typealias count = i64

let limit:count = 10
let origin:point = {7, 8}

struct left { n: i64; other: right^ }
struct right { n: i64; other: left^ }
// out: 25 color 1 5 10 7
// out: 2 1 7
