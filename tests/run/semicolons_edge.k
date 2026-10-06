// where a line ends a statement and where it goes on (#35), edge cases
// from review
#import <stdlib.h> as C

struct point { x:i64; y:i64 }
struct box { scale:i64 }

var g:i64 = 0
let mask:u32 = (1 << 4)

// a prototype of a method ends at its line
let point.twice():i64
let point.twice():i64 { self.x * 2 }

// a `{` on the line after a head is the body
let square(x:i64):i64
{
    x * x
}

let apply(x:i64, f:(i64):i64):i64 { f(x) }
let tick() { g += 1 }
let twice(x:i64):i64 { x * 2 }

// in a function with a result, `return` takes the next line
let long_one(a:i64, b:i64):i64 {
    return
        a * 100 + b
}

// one expression: an annotation, a product broken before an operator,
// or written with its `;`
let widen(n:i32):i64 { n:i64 }
let scaled(n:i32):i64 {
    n:i64
        * 1000
}
let area(w:i64, h:i64):i64 {
    w * h
        + 1
}
let mul(a:i64, b:i64):i64 { a * b; }
let named():cstr { abs(-3).typename }

let main():i32 {
    // a `(...)`, a property, a conversion or sizeof(T) at the end of a
    // line, before a line that starts with a name, `(` or `{`
    var xs:[i64](2) = [1, 2]
    var q:any^ := &xs[0]
    let a:i64 = (xs[1] + 1)
    let s:cstr := a.hex
    (q as i64^)^ = 9
    let b:box = {7}
    let y:i64 = b.scale
    (q as i64^)^ += 1
    let d:i64 = 7:i64
    (q as i64^)^ += d
    let n:u64 = sizeof(point)
    {
        tick()
    }
    let t:i64 = (a)
    {
        tick()
    }
    println(a, " ", s, " ", xs[0], " ", y, " ", n, " ", t, " ", g, " ", mask)

    // a `{` on the line after a call starts a block
    tick()
    {
        tick()
    }
    _Pragma("GCC diagnostic push")
    _Pragma("GCC diagnostic pop")
    println(g)

    // inside brackets, lines do not matter
    println(apply(3)
        { $0 * 2 }, " ", twice(apply(3)
        { $0 + 1 }))
    let ys:[i64](2) = [
        apply(1)
        { $0 + 1 },
        apply(2)
        { $0 + 2 }
    ]
    println(ys[0], " ", ys[1])

    // ?, :, as and [ at the start of a line go on
    let c:i64 = g > 2
        ? 10
        : 20
    let u:u8 = c
        as u8
    let z:i64 = ys
        [1]
    println(c, " ", u, " ", z)

    // do ... while (cond) at the end of a line
    var m = 3
    do {
        m -= 1
    } while (m > 0)
    println(m)

    let h:(i32):i64 := { (k:i32):i64 in k:i64 * 2 }
    println(long_one(1, 2), " ", square(3), " ", widen(5), " ", scaled(2), " ", area(3, 4))
    println(mul(3, 4), " ", h(4), " ", apply(3) { g:i64 * $0 }, " ", named(), " ", (point){4, 0}.twice())
    return 0
}
// out: 3 +0x3 17 7 16 3 2 16
// out: 4
// out: 6 8
// out: 2 4
// out: 10 10 4
// out: 0
// out: 102 9 5 2000 13
// out: 12 8 12 i32 8
