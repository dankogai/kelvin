// .lazy makes the map or filter after it lazy, and stands for nothing alone (#323)
struct span { lo: int64; hi: int64 }
struct span_walk { at: int64; hi: int64 }
var span_walk.next():int64? {
    if .at >= .hi { return none }
    .at += 1
    return .at - 1
}
let span.makeIterator():span_walk { return {.lo, .hi} }
let main():int32 {
    let s:span = {1, 4}
    println(s.lazy.reduce(0) { $0 + $1 })
    return 0
}
// error: '.lazy' makes '.map' or '.filter' after it lazy
