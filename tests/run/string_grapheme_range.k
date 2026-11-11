// s[i] past a String's graphemes ends the program (#522), as an Array's
// index does
let main():int32 {
    var s = $"éx"
    println(s[1])
    println(s[2])
    return 0
}
// out: x
// exit: 1
// err: kelvin: index 2 is out of range: the String has 2 graphemes
