// a Sequence reads itself to give a fresh iterator: its makeIterator is
// a let method (#321)
struct span { lo: int64; hi: int64 }
struct span_walk { at: int64; hi: int64 }
var span_walk.next():int64? { none }
var span.makeIterator():span_walk { return {.lo, .hi} }
let main():int32 {
    var s:span = {1, 4}
    for x in s { println(x) }
    return 0
}
// error: a Sequence gives a fresh iterator by its makeIterator(), a let method that takes nothing and gives a value whose 'var next():T?' gives each value: write 'let span.makeIterator():I'
