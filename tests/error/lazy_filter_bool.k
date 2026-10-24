// a lazy filter says whether to keep a value, a bool (#323)
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
    let l = s.lazy.filter { $0 * 2 }
    return 0
}
// error: '.lazy.filter'
