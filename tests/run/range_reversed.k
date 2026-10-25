// r.reversed() (#378): an Iterator<T> of its values from the last down,
// lazily, walked once; it never steps past lo, and lo... has no end to
// start from
let ends(lo:int64):Range { return lo... }
let main():int32 {
    for i in (0..<5).reversed() { print(i, ",") }
    for i in (1...3).reversed() { print(i, ",") }
    for i in (5..<1).reversed() { print(i, ",") }
    let b:Range<uint8> = 0...3
    for i in b.reversed() { print(i, ",") }
    println()
    println((0..<5).reversed().map { $0 * 10 }, " ", (1...9).reversed().prefix(3).map { $0 }, " ",
            (0..<4).reversed().lazy.filter { $0 % 2 == 1 }.map { $0 })
    println(ends(0).prefix(3).reversed().map { $0 })
    println(ends(0).reversed().map { $0 })
    return 0
}
// out: 4,3,2,1,0,3,2,1,3,2,1,0,
// out: [40, 30, 20, 10, 0] [9, 8, 7] [3, 1]
// out: [2, 1, 0]
// exit: 1
// err: kelvin: this Range has no end, and '.reversed()' walks one from its end: take its first few, '.prefix(n)'
