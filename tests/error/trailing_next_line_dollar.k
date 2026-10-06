// error: '$0' is a parameter of an anonymous function, and this is not in one; a trailing function starts on the line of the call's ')'
var ticks:i64 = 0
let tick() { ticks += 1 }
let main():i32 {
    tick()
    {
        println($0)
    }
    return 0
}
