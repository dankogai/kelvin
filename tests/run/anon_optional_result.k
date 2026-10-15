// an anonymous function with an Optional result (#114): {(a:T):U? in ...}
// is read as a signature, the ? being the type's, since `in` follows;
// and its one-expression body is wrapped as `return` wraps it: a U, or
// none
let apply(f:(cstr, int64):i64?, n:i64):i64 {
    var r = f("k", n)
    return r ?? -1
}
let main():i32 {
    println(apply({ (k:cstr, v:i64):i64? in none }, 3))
    println(apply({ (k:cstr, v:i64):i64? in v * 2 }, 3))
    println(apply({ (k:cstr, v:i64):i64? in
        if v > 2 { return v }
        return none
    }, 3))
    let half := { (v:i64):i64? in
        if v % 2 == 0 { return v / 2 }
        return none
    }
    var h = half(8)
    var o = half(7)
    println(h.cstr, " ", o.cstr)
    var r = Optional<i64>(4).map { (v:i64):f64? in v / 2.0 }
    println(r.cstr)
    return 0
}
// out: -1
// out: 6
// out: 3
// out: some(4) none
// out: some(some(2))
