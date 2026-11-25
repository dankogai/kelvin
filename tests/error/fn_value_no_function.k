// text where a function goes is no function (#748): C took it with a
// warning, and the program ran into it
let num(f:(int64):int64):int64 { f(1) }
let main():int32 {
    println(num("a"))
    return 0
}
// error: this is cstr, where (i64):i64 goes
