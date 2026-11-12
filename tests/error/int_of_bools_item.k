// T([b, ...]) is of bools (#530): an integer is no bit
let main():int32 {
    println(u8([true, 1]))
    return 0
}
// error: u8([b, ...]) is of bools, place 0 first, and this is i64
