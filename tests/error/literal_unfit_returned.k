// of a return (#663)
let f():u8 { return 300 }
let main():int32 {
    println(f())
    return 0
}
// error: 300 does not fit u8, whose values are 0 to 255
