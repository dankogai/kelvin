// r == s and r != s (#376): equal when of the same kind and bounds, as
// they print, as Swift's; ranges of two integer types compare by value,
// and an Array, an Optional of Ranges compare by them
let main():int32 {
    let r = 0..<5
    let b:Range<uint8> = 0..<5
    let e8:Range<uint8> = 0...
    println(r == 0..<5, " ", r != 0..<5, " ", r == 0...4, " ", 0..<0 == 1..<1, " ", r == b, " ", e8 == 0..., " ",
            (0...) == 1..., " ", r.prefix(9) == r)
    if r == b && 1...3 != 1..<3 { println("yes") }
    let rs = $[0..<1, 2...3]
    println(rs.contains(2...3), " ", rs == $[0..<1, 2...3], " ", rs.firstIndex(2...3))
    let o:Range? = 0..<2
    println(o == 0..<2, " ", o == 1..<2)
    return 0
}
// out: true false false false true true false true
// out: yes
// out: true true some(1)
// out: true false
