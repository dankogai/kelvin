// for c in s of uchrs (#480): a fixed array of uchr and a uchr^ stop at
// U+0000, as an array of numbers stops at 0; a written type converts each
// element as T(v) does, a uchr's codepoint, or uchr(v) of an integer
let count(xs:[uchr](4)):i64 {
    var n = 0
    for _ in xs {
        n += 1
    }
    return n
}
let main():int32 {
    var f = [uchr](4)
    f[0] = uchr("é")
    f[1] = uchr("z")
    f[3] = uchr("q")
    for c in f {
        print(c, " ")
    }
    println(count(f))
    let p:uchr^ := &f[0]
    print("p")
    for c in p {
        print(" ", c.codepoint)
    }
    println()
    print("b")
    for b:u32 in f {
        print(" ", b)
    }
    let s = String("aω")
    for b:i64 in s {
        print(" ", b)
    }
    let a = $[uchr("x"), uchr(0), uchr("y")]
    for b:u8 in a {
        print(" ", b)
    }
    println()
    var n = [i32](3)
    n[0] = 75
    n[1] = 0x263A
    for c:uchr in n {
        print(c)
    }
    println()
    return 0
}
// out: é z 2
// out: p 233 122
// out: b 233 122 97 969 120 0 121
// out: K☺
// c: (*_kv_c_ptr).cp != 0
