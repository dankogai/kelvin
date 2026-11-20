// a loop that a break leaves goes on past it (#625)
let first(a:i64):i64 {
    while true {
        if a > 0 { break }
        return a
    }
}
let main():int32 {
    println(first(2))
    return 0
}
// error: 'first' can reach the end of its body with no value: every path of a function with a result returns one
