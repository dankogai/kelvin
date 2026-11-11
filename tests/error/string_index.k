// s[i] is grapheme i of a String (#522), i an integer: a String was not
// indexed before (#55); a double is no index
let main():int32 {
    var s = String("héllo")
    let x:f64 = 1.5
    println(s[x])
    return 0
}
// error: s[i] is grapheme i of a String, i an integer, and this is f64
