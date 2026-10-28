// String(&b) of bytes that are not UTF-8 ends the program (#55); b.string()
// is the form that hands the error back (#405)
let main():int32 {
    var b = Bytes([0x61, 0xFF])
    println(b.string())
    let s = String(&b)
    println(s)
    return 0
}
// out: err(1)
// exit: 1
// err: kelvin: malformed UTF-8: a String holds well-formed text only
