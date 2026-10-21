// xs.map(f) and xs.map { ... } of an Array (#182): a new Array of f of each
// element, of whatever type f gives, an owner too; an element that is an
// owner is lent to an anonymous f (#244), and a copy given to a named one
// or to a parameter written var; the Array stays as it was
struct point { x: int64; y: int64 }
let label(n:int64):String { $`#${n}` }
let main():int32 {
    var xs = $[1, 2, 3]
    var doubled = xs.map { $0 * 2 }
    var halves = xs.map { (n:int64):float64 in n as float64 / 2.0 }
    var labels = xs.map(label)
    var even = xs.map { $0 % 2 == 0 }
    println(doubled, " ", halves, " ", labels, " ", even, " ", xs)
    var names = $[$"ann", $"bob"]
    var counts = names.map { $0.count as int64 }
    var shout = names.map { (var s:String):String in
        s += "!"
        return s
    }
    println(counts, " ", shout, " ", names)
    var pts = xs.map { (n:int64):point in (point){n, n * n} }
    var ys = pts.map { $0.y }
    var nested = xs.map { (n:int64):Array<int64> in Array<int64>(n as size_t) }
    var sizes = nested.map { $0.count as int64 }
    var empty = Array<int64>()
    var none = empty.map { $0 + 1 }
    var again = doubled.map { $0 + 1 }
    var neg = xs.map { -$0 }
    println(ys, " ", sizes, " ", none.count, " ", again, " ", neg)
    return 0
}
// out: [2, 4, 6] [0.5, 1.0, 1.5] ["#1", "#2", "#3"] [false, true, false] [1, 2, 3]
// out: [3, 3] ["ann!", "bob!"] ["ann", "bob"]
// out: [1, 4, 9] [1, 2, 3] 0 [3, 5, 7] [-1, -2, -3]
