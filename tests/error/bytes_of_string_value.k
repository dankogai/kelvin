// Bytes(s) of a String a call gives is written Bytes(&s) (#412)
let name():String { return $"kelvin" }
let main():int32 {
    let b = Bytes(name())
    println(b)
    return 0
}
// error: Bytes(s) of a String is written Bytes(&s), a copy of its bytes (#291)
