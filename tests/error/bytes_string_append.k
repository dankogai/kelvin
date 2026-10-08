// a Bytes takes a String through its bytes (#55)
let main():i32 {
    var s = String("x")
    var b = Bytes("y")
    b += &s
    return 0
}
// error: a Bytes takes bytes: give the String's bytes, 's.bytes'
