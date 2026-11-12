// a method of an integer, called on a literal or on arithmetic of
// literals, takes it as the i64 it is (#538): bare, C read 1 as an int
// and 1 << 40 as a long, which no method of an i64 was of, and
// 1.over(3) was C's error
extend i64 {
    let twice():i64 { self * 2 }
    let plus(n:i64):i64 { self + n }
}
let main():int32 {
    let n = 5
    println(21.twice(), " ", (-4).twice(), " ", 1.plus(2), " ", n.twice(), " ", (0x10).plus(1), " ", 3.twice().plus(1), " ", (1 << 40).twice(), " ", (-9223372036854775807 - 1).plus(1))
    return 0
}
// out: 42 -8 3 10 17 7 2199023255552 -9223372036854775807
