// a function with a result whose body can reach its end is kelvinc's
// error, where it was C's warning and the program ran on what C left
// (#625)
let sign(a:i64):i64 {
    if a > 0 { return 1 }
    if a < 0 { return -1 }
}
let main():int32 {
    println(sign(2))
    return 0
}
// error: 'sign' can reach the end of its body with no value: every path of a function with a result returns one
