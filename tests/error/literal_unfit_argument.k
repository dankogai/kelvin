// of an argument (#663)
let f(c:u8):u8 { c }
let main():int32 {
    println(f(256))
    return 0
}
// error: 256 does not fit u8, whose values are 0 to 255
