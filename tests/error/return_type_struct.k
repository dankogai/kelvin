// a struct where a number is returned (#627)
struct point { x: i64 }
let first(p:point):i64 {
    return p
}
let main():int32 {
    var p:point = {1}
    println(first(p))
    return 0
}
// error: 'first' returns an i64, and this is point
