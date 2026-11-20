// so of a method (#627)
struct point { x: i64 }
let point.moved(d:i64):i64 { .x + d }
let main():int32 {
    var p:point = {1}
    println(p.moved(1, 2))
    return 0
}
// error: '.moved' of point takes 1 argument, and this call gives 2
