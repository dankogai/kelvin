// an error of a value that is a member read is said at its . (#757),
// kelvinc's place, where kc said it at the member's name
struct ops { f:(int64):int64, n:int64 }
let num(f:(int64):int64):int64 { f(1) }
let twice(x:int64):int64 { x * 2 }
let main():int32 {
    var o:ops = {twice, 1}
    println(num(o.n))
    return 0
}
// error: this is i64, where (i64):i64 goes
