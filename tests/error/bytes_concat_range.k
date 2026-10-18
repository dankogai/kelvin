// a byte added to a Bytes with '+' (#188) is 0 to 255, as in Bytes([...])
let main():int32 {
    var b = Bytes("a")
    var c = b + 256
    return 0
}
// error: a byte of '+' is 0 to 255, and this is 256
