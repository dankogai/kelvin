// a byte of Bytes([...]) (#172) is 0 to 255
let main():int32 {
    var b = Bytes([0, 256])
    return 0
}
// error: a byte of Bytes([...]) is 0 to 255, and this is 256
