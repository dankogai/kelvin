// Bytes.fromBase64 takes text, or a String borrowed (#155)
let main():int32 {
    var s = $"TWFu"
    var b = Bytes.fromBase64(s)
    return 0
}
// error: Bytes.fromBase64 of a String takes a borrow: write '&s'
