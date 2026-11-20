// so of an anonymous function (#625)
let main():int32 {
    let pos := { (a:i64):i64 in if a > 0 { return 1 } }
    println(pos(2))
    return 0
}
// error: this anonymous function can reach the end of its body with no value: every path of a function with a result returns one
