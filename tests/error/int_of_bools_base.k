// T(bools) takes no base (#530): a base is for text
let main():int32 {
    println(u8([true, false], 2))
    return 0
}
// error: a base is for reading text, as in u8("755", 8); u8 of a [bool] is of its bools, place 0 first
