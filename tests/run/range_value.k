// Range<T> (#373): a range is a value, the integers from lo up to hi, a
// Sequence with map, filter, reduce, flatMap, lazy and prefix; lo... has
// no end and walks to its type's largest, ..<hi and ...hi start at 0
struct span { name: String; r: Range<uint8> }
let squares(r:Range):$[int64] { return r.map { $0 * $0 } }
let digits():Range<int32> { return 0...9 }
let main():int32 {
    let n = 3
    let r = 0..<5
    let c = 1...3
    let e = 0...
    let m = -n..<n
    println(r, " ", c, " ", e, " ", ..<4, " ", ...2, " ", m, " ", 5..<1)
    for i in m { print(i, ",") }
    for i in ..<2 { print(i, ",") }
    for i in 0... {
        if i > 2 { break }
        print(i, ",")
    }
    println()
    println(r.map { $0 * 10 }, " ", c.filter { $0 % 2 == 1 }, " ", r.reduce(0) { $0 + $1 }, " ",
            c.flatMap { $[$0, $0] }, " ", (5..<1).map { $0 })
    println(e.prefix(5), " ", r.prefix(2), " ", r.prefix(9), " ", c.prefix(0), " ", e.prefix { $0 < 4 }.map { $0 })
    println(e.lazy.map { $0 * 2 }.prefix(4).map { $0 }, " ", e.lazy.filter { $0 % 3 == 0 }.prefix(3).map { $0 })
    println(squares(1...4), " ", digits())
    let b:Range<uint8> = 250...
    for x in b { print(x, ",") }
    println(" ", b, " ", b.prefix(3), " ", b.prefix(10))
    let s:span = {$"s", 0..<4}
    let rs = $[0..<1, 2...3]
    let o:Range? = 0..<2
    println(s, " ", rs, " ", o, " ", `e is ${e}`)
    let xs = $[1, 2, 3, 4, 5]
    println(xs[1..<3], " ", xs[2...], " ", xs[..<2], " ", xs[...1])
    return 0
}
// out: 0..<5 1...3 0... 0..<4 0...2 -3..<3 5..<1
// out: -3,-2,-1,0,1,2,0,1,0,1,2,
// out: [0, 10, 20, 30, 40] [1, 3] 10 [1, 1, 2, 2, 3, 3] []
// out: 0..<5 0..<2 0..<5 1..<1 [0, 1, 2, 3]
// out: [0, 2, 4, 6] [0, 3, 6]
// out: [1, 4, 9, 16] 0...9
// out: 250,251,252,253,254,255, 250... 250..<253 250...255
// out: {name: "s", r: 0..<4} [0..<1, 2...3] some(0..<2) e is 0...
// out: [2, 3] [3, 4, 5] [1, 2] [1, 2]
