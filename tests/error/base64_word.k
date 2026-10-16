// b.toBase64 takes the words url and nopad (#155)
let main():int32 {
    var b = Bytes("x")
    var s = b.toBase64(padded)
    return 0
}
// error: '.toBase64' takes the words url and nopad, in either order, or nothing
