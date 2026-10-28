// b.string() (#405) is a Result<String, i64>: the String, or the offset of
// the first byte where the UTF-8 breaks, to handle, not die of; String(&b)
// stays the checked form, which ends the program
let textOf(b:const Bytes^):Result<String, i64> {
    let s = try b^.string()
    return s.copy()
}
let main():int32 {
    var good = Bytes("héllo")
    var bad = Bytes([0x61, 0x62, 0xE2, 0x82, 0x28, 0x63])
    var r = good.string()
    println(r, " ", r.is(ok), " ", r.ok.count)
    var e = bad.string()
    println(e, " ", e.err)
    if let s = good.string() { println(s, " ", s.count) }
    if let err(at) = bad.string() { println("not UTF-8 at byte ", at) }
    println(bad.string() ?? $"?", " ", good.string() ?? $"?")
    println(good.string().is(ok), " ", bad.string().is(err))
    switch bad.string() {
    case ok(s): println(s)
    case err(at): println("at ", at)
    }
    println(textOf(&good), " ", textOf(&bad))
    var empty = Bytes()
    println(empty.string())
    var u = Bytes(&$"héllo")
    println(u.string() == $"héllo")
    return 0
}
// out: ok("héllo") true 5
// out: err(2) 2
// out: héllo 5
// out: not UTF-8 at byte 2
// out: ? héllo
// out: true true
// out: at 2
// out: ok("héllo") err(2)
// out: ok("")
// out: true
