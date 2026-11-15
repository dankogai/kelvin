// with <Rational> alone, modules/math+Rational.k is not read (#551,
// #552): CBR is the program's own, and a BigRat has no .i of its own
#import <Rational>
struct CBR { n: i64 }
extend BigRat {
    let i:i64 { 7 }
}
let conj(z:CBR):CBR { (CBR){0 - z.n} }
let main():int32 {
    println(conj((CBR){3}), " ", 1n.over(2n).i, " ", 1n.over(3n) + 1n.over(6n))
    return 0
}
// out: {n: -3} 7 (1n/2n)
