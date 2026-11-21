// a negative literal where an unsigned integer goes (#663)
let main():int32 {
    let u:u32 = -1
    println(u)
    return 0
}
// error: -1 does not fit u32, whose values are 0 to 4294967295
