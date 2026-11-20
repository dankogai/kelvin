// so of a method and an attribute (#625)
struct point { x: i64 }
let point.side():i64 {
    if .x > 0 { return 1 }
}
let main():int32 {
    var p:point = {2}
    println(p.side())
    return 0
}
// error: 'point.side' can reach the end of its body with no value: every path of a function with a result returns one
