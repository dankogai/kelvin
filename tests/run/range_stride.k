// r.stride(n) (#379): an Iterator<T> of every n-th value, from lo up, or of
// a negative n, from its last value down; it never steps past T's
// largest or smallest, and lo... has no end to walk down from
let ends(lo:int64):Range { return lo... }
let main():int32 {
    for i in (0..<10).stride(3) { print(i, ",") }
    for i in (0..<10).stride(-3) { print(i, ",") }
    for i in (5..<1).stride(2) { print(i, ",") }
    println()
    let w:Range<int32> = -2147483648...2147483647
    println(w.stride(2000000000).map { $0 }, " ", w.stride(-2000000000).map { $0 })
    let b:Range<uint8> = 0...255
    println(b.stride(100).map { $0 }, " ", (0...).stride(5).prefix(4).map { $0 })
    let big:Range<int64> = 9223372036854775800...
    println(big.stride(3).map { $0 }, " ", (1...10).stride(4).reduce(0) { $0 + $1 })
    var it = (0..<4).stride(2)
    println(it.next(), " ", it.next(), " ", it.next())
    var n = 0
    println(ends(0).prefix(10).stride(-4).map { $0 })
    println((0..<3).stride(n).map { $0 })
    return 0
}
// out: 0,3,6,9,9,6,3,0,
// out: [-2147483648, -147483648, 1852516352] [2147483647, 147483647, -1852516353]
// out: [0, 100, 200] [0, 5, 10, 15]
// out: [9223372036854775800, 9223372036854775803, 9223372036854775806] 15
// out: some(0) some(2) none
// out: [9, 5, 1]
// exit: 1
// err: kelvin: '.stride(n)' stepped by 0, which never moves
