// a subscript's index may be lent, i:lent T, as a function's parameter (#510):
// its caller keeps it, and an owner an expression gives is held for the
// call (#614)
struct box { n: i64 }
extend box {
    let [](i:lent BigInt):i64 { (i + .n).i64 }
    let [](s:lent String, k:i64):i64 { s.count as i64 * k + .n }
}
let main():int32 {
    let x:box = {1}
    var b = 5n
    let s = $"abc"
    println(x[b], " ", x[b * 2], " ", x[3n], " ", b, " ", x[s, 2], " ", x[$"de", 3], " ", s)
    b = 7n
    println(x[b], " ", b)
    return 0
}
// out: 6 11 4 5n 7 7 abc
// out: 8 7n
