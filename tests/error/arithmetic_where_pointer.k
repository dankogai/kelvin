// arithmetic of numbers is a number where a pointer goes (#787), as
// kelvinc names what it sees no type of: kc left it to C
let main():int32 {
    var x:int64 = 1
    var p:int64^ := x + 1
    return 0
}
// error: 'p' is an i64^, and this is a number
