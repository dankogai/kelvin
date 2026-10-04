// more of #35's rules, from the second review: the expression a body
// returns, return before case, default and labels, break and goto at a
// line end, and lines inside brackets
#import <stdio.h> as C
#import <stdint.h> as C
#import <stdlib.h> as C

struct box { n:i64 }
box.show() { println("box ", self.n) }

// one expression that starts with a name kelvinc cannot see, or with an
// annotation to a C typedef, before `?` or before `as`
buffer_bytes(n:i64):i64 { BUFSIZ * n }
buffer_bytes2(n:i64):i64 { BUFSIZ * n; }
max_rand():f64 { RAND_MAX:f64 }
to_u(n:i64):uint8_t { n:uint8_t }
pick(flags:i32, a:i64, b:i64):i64 { flags:bool ? a : b }
half(n:i32):f64 { n:i64 as f64 / 2.0 }
twice(x:i64):i64 { x * 2 }

// `return` at the end of a line, before a case, a default or a label
describe(n:i64) {
    switch (n) {
    case 0:
        println("zero")
        return
    case 1:
        println("one")
        return
    default:
        println("many")
    }
    if n > 5 {
        if n == 6 {
            goto big
        }
        return
    big:
        println("big")
    }
}
var calls:i64 = 0
none_first(xs:i64^, n:i64) {
    for (var i:i64 = 0; i < n && xs[i] != 0; i += 1)
        return
    calls += 1
}
cleanup(fail:bool) {
    if fail {
        goto out
    }
    println("done")
    return
    {
    out:
        println("failed")
    }
}
quiet() {
    return;
    println("never")
}

// a call before a case may drop its value: the case falls through
var hits:i64 = 0
bump():i64 { hits += 1; return hits }
count_down(n:i64):i64 {
    switch (n) {
    case 2:
        bump()
    case 1:
        bump()
    default:
        return hits
    }
}

// a `*` at the start of a line goes on with a product, unless what it
// touches is assigned
let PI = 3.141592653589793
sphere(r:f64):f64 {
    return 4.0 / 3.0
        *PI*r*r*r
}

main():i32 {
    println(buffer_bytes(2) == buffer_bytes2(2), " ", max_rand() > 0.0, " ", to_u(300), " ", pick(1, 10, 20), " ",
            half(5))
    describe(0)
    describe(1)
    describe(2)
    describe(6)
    none_first(&calls, 0)
    cleanup(false)
    cleanup(true)
    quiet()
    println(calls, " ", count_down(2))

    // break and goto end at their line
    var n = 0
    for i in 0..<10 {
        if i == 3 {
            break
        }
        n += i
    }
    var tries = 0
again:
    tries += 1
    if tries < 3 {
        goto again
    }
    println(n, " ", tries)

    // a `{` on the line after a method call starts a block
    let b:box = {4}
    b.show()
    {
        println("block")
    }

    // inside brackets, lines do not matter
    let a = 3
    let c = 4
    let total:f64 = 2.0
    let rate:f64 = 0.5
    println(twice
        (3), " ", a
        *c, " ", total
        *(1.0 + rate), " ", sphere(1.0) > 4.18)

    // heads with their `{` on the next line, and a statement after a block
    var k = 0
    if k == 0
    {
        k = 1
    }
    else
    {
        k = 2
    }
    while k < 3
    {
        k += 1
    }
    for i in 0..<2
    {
        k += i
    }
    switch (k)
    {
    case 4:
        println("four")
    }
    if k > 0 { k = 10 } k += 1
    if true { _Pragma("GCC diagnostic push") }
    _Pragma("GCC diagnostic pop")
    let to_size := { (m:i64):size_t in m:size_t * 2 }
    println(k, " ", to_size(4))
    return 0
}
// out: true true 44 10 2.5
// out: zero
// out: one
// out: many
// out: many
// out: big
// out: done
// out: failed
// out: 1 2
// out: 3 3
// out: box 4
// out: block
// out: 6 12 3.0 true
// out: four
// out: 11 8
