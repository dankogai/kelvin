// a u8 is shifted as the int C makes of it, 32 bits (#665)
let main():int32 {
    var x:u8 = 5
    println(x << 32)
    return 0
}
// error: '<< 32' shifts a u8 by 32, the width or more of the i32 C makes of it, which C leaves undefined
