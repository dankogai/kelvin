// atomic is of a number, a bool or a pointer (#642)
struct point { x: i64; y: i64 }
var p:atomic point = {0, 0}
let main():int32 {
    println(p.x)
    return 0
}
// error: 'atomic' is of a number, a bool or a pointer, which C's atomic operations change at once (#642), and this is
