// a struct's member is p.x, and p^.x is of a pointer (#627)
struct point { x: i64 }
let main():int32 {
    var p:point = {1}
    println(p^.x)
    return 0
}
// error: '^' reads what a pointer points at, and 'p' is a point
