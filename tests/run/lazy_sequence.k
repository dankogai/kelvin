// s.lazy.map(f), s.lazy.filter(f) (#323), Swift's: a lazy Sequence, whose
// iterator calls the base's next, and f, only when it is asked: nothing
// is gathered, a break stops the calls, and an endless Sequence is
// walked in part; a lazy Sequence's own map and filter are lazy, its
// reduce and flatMap eager, as any Sequence's
struct span { lo: int64; hi: int64 }
struct span_walk { at: int64; hi: int64 }
var span_walk.next():int64? {
    if .at >= .hi { return none }
    .at += 1
    return .at - 1
}
let span.makeIterator():span_walk { return {.lo, .hi} }
let tens(n:int64):int64 {
    println("tens of ", n)
    return n * 10
}
let main():int32 {
    let s:span = {1, 5}
    let m = s.lazy.map(tens)
    println("made")
    for x in m {
        println("got ", x)
        if x == 20 { break }
    }
    let evens = s.lazy.filter { $0 % 2 == 0 }
    for x in evens { print(x, ",") }
    for x in evens { print(x, ",") }
    println()
    for x in s.lazy.map({ $0 * $0 }).filter({ $0 > 3 }) { print(x, ",") }
    println()
    println(s.lazy.map { $0 + 100 }.reduce(0) { $0 + $1 }, " ", s.lazy.filter { $0 > 2 }.flatMap { Array<int64>([$0 * 2]) })
    let endless:span = {0, 1000000000}
    for x in endless.lazy.filter({ $0 % 7 == 3 }) {
        if x > 30 { break }
        print(x, ",")
    }
    println()
    return 0
}
// out: made
// out: tens of 1
// out: got 10
// out: tens of 2
// out: got 20
// out: 2,4,2,4,
// out: 4,9,16,
// out: 410 [6, 8]
// out: 3,10,17,24,
