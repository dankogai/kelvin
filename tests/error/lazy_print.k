// a lazy Sequence has no text: its values are made as they are asked for (#323)
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
    println(s.lazy.map { $0 * 2 })
    return 0
}
// error: println cannot show a lazy Sequence, whose values are made only as they are asked for: walk it with for
