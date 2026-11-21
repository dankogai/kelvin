// a literal that does not fit the type written is kelvinc's error (#663),
// where C only warned and made 300 a u8 of 44
let main():int32 {
    let c:u8 = 300
    println(c)
    return 0
}
// error: 300 does not fit u8, whose values are 0 to 255
