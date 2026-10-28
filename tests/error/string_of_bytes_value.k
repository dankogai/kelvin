// String(b) of a Bytes a call gives is written String(&b) (#412)
let raw():Bytes { return Bytes("hb") }
let main():int32 {
    let s = String(raw())
    println(s)
    return 0
}
// error: String(b) of a Bytes is written String(&b), checked, or b.string() for a Result
