// a converter converts a number or reads text (#513): of a pointer that is
// no text it is an error, where it was C's cast to an integer; the address
// is p.addr, and `p as i64` is C's cast
let main():int32 {
    var n:i64 = 7
    let p:i64^ := &n
    println(i64(p))
    return 0
}
// error: i64(v) converts a number, or reads one from text, and i64^ is neither: an address is '.addr', and 'v as i64' is C's cast (#513)
