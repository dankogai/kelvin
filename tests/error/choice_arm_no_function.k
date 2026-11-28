// each arm of a choice where a function goes is asked (#791), as kc
// asks it: kelvinc built this by its first arm's type
let twice(n:int64):int64 { return n * 2 }
let take(f:(int64):int64):int64 { return f(1) }

let main():int32 {
    var x:int64 = 1
    println(take(true ? twice : x))
    return 0
}
// error: this is i64, where (i64):i64 goes
