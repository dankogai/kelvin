// .lazy is a Sequence's, which gives a fresh iterator each time (#323)
struct span { lo: int64; hi: int64 }
struct span_walk { at: int64; hi: int64 }
var span_walk.next():int64? {
    if .at >= .hi { return none }
    .at += 1
    return .at - 1
}
let span.makeIterator():span_walk { return {.lo, .hi} }
let main():int32 {
    var w:span_walk = {0, 3}
    println(w.lazy.map { $0 * 2 })
    return 0
}
// error: '.lazy' is a Sequence's, whose makeIterator gives a fresh iterator each time, and this is an iterator
