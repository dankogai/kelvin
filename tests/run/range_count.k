// r.count and r.contains(x) (#374): its values, a u64 as an Array's
// count, and whether x is one of them, of any integer type; one without
// an end has a contains, and a count only of its first few
let ends(lo:int64):Range { return lo... }
let main():int32 {
    let r = 0..<5
    let b:Range<uint8> = 250...255
    let w:Range<uint64> = 0...18446744073709551614
    let n:int8 = -1
    println(r.count, " ", (1...3).count, " ", (5..<1).count, " ", (3...3).count, " ", b.count, " ", w.count, " ", r.count.typename)
    println(r.contains(4), " ", r.contains(5), " ", (1...3).contains(3), " ", b.contains(n), " ", b.contains(255), " ",
            (0...).contains(9), " ", (-3..<3).contains(-3))
    if r.contains(2) && !r.contains(-1) { println("yes") }
    println(ends(2).prefix(4).count, " ", ends(2).contains(1))
    println(ends(2).count)
    return 0
}
// out: 5 3 0 1 6 18446744073709551615 u64
// out: true false true false true true true
// out: yes
// out: 4 false
// exit: 1
// err: kelvin: this Range has no end, and '.count' counts one to its end: take its first few, '.prefix(n)'
