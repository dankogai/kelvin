// a function of const elements goes where its very type goes, not where
// one that may change them goes (#754): the function's type is named as
// it is written, [const i64](3)
let fixed(m:[const int64](3)):int64 { m[0] }
let take3(f:([int64](3)):int64):int64 {
    var a:[int64](3) = [7, 8, 9]
    return f(a)
}
let main():int32 {
    println(take3(fixed))
    return 0
}
// error: no function 'fixed' is ([i64](3)):i64: C's function of the name is not taken where a Kelvin function has it (#223); declare C's beside it, as in 'let fixed(x:f64):f64'
