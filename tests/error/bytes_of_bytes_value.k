// Bytes(x) of a Bytes an expression gives is one already (#412)
let raw():Bytes { return Bytes("hb") }
let main():int32 {
    let b = Bytes(raw())
    println(b)
    return 0
}
// error: Bytes(x) of a Bytes is one already: leave out Bytes(...)
