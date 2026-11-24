// a member that is a function is called as its type says (#740)
struct ops { f:(int64, int64):int64 }
let two(a:int64, b:int64):int64 { a + b }
let main():int32 {
    var o:ops = {two}
    println(o.f(1, 2, 3))
    return 0
}
// error: this function, of type (i64, i64):i64, takes 2 arguments, and it is given 3
