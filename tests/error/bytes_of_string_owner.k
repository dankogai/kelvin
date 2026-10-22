// Bytes(s) of a String is refused, as an owner copied; its bytes are
// Bytes(&s) (#291), which the message names
let main():int32 {
    var s = $"abc"
    println(Bytes(s))
    return 0
}
// error: Bytes(s) of a String is written Bytes(&s), a copy of its bytes (#291)
