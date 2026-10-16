// where a line ends a statement and where it goes on (#35), edge cases
// from review
#import <stdlib.h> as C

struct point { x:int64; y:int64 }
struct box { scale:int64 }

var g:int64 = 0
let mask:uint32 = (1 << 4)

// a prototype of a method ends at its line
let point.twice():int64
let point.twice():int64 { .x * 2 }

// a `{` on the line after a head is the body
let square(x:int64):int64
{
    x * x
}

let apply(x:int64, f:(int64):int64):int64 { f(x) }
let tick() { g += 1 }
let twice(x:int64):int64 { x * 2 }

// in a function with a result, `return` takes the next line
let long_one(a:int64, b:int64):int64 {
    return
        a * 100 + b
}

// one expression: an annotation, a product broken before an operator,
// or written with its `;`
let widen(n:int32):int64 { n:int64 }
let scaled(n:int32):int64 {
    n:int64
        * 1000
}
let area(w:int64, h:int64):int64 {
    w * h
        + 1
}
let mul(a:int64, b:int64):int64 { a * b; }
let named():cstr { abs(-3).typename }

let main():int32 {
    // a `(...)`, a property, a conversion or sizeof(T) at the end of a
    // line, before a line that starts with a name, `(` or `{`
    var xs:[int64](2) = [1, 2]
    var q:any^ := &xs[0]
    let a:int64 = (xs[1] + 1)
    let s:cstr := a.hex
    (q as int64^)^ = 9
    let b:box = {7}
    let y:int64 = b.scale
    (q as int64^)^ += 1
    let d:int64 = 7:int64
    (q as int64^)^ += d
    let n:uint64 = sizeof(point)
    {
        tick()
    }
    let t:int64 = (a)
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
    let ys:[int64](2) = [
        apply(1)
        { $0 + 1 },
        apply(2)
        { $0 + 2 }
    ]
    println(ys[0], " ", ys[1])

    // ?, :, as and [ at the start of a line go on
    let c:int64 = g > 2
        ? 10
        : 20
    let u:uint8 = c
        as uint8
    let z:int64 = ys
        [1]
    println(c, " ", u, " ", z)

    // do ... while (cond) at the end of a line
    var m = 3
    do {
        m -= 1
    } while (m > 0)
    println(m)

    let h:(int32):int64 := { (k:int32):int64 in k:int64 * 2 }
    println(long_one(1, 2), " ", square(3), " ", widen(5), " ", scaled(2), " ", area(3, 4))
    println(mul(3, 4), " ", h(4), " ", apply(3) { g:int64 * $0 }, " ", named(), " ", (point){4, 0}.twice())
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
