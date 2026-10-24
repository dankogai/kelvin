// map walks an iterator by its var next(), which changes it (#319)
struct countdown { n: int64 }
var countdown.next():int64? { if .n == 0 { return none }; .n -= 1; return .n + 1 }
let main():int32 {
    let c:countdown = {3}
    println(c.map { $0 * 2 })
    return 0
}
// error: '.map' walks an iterator by its var next(), which changes 'c', a let: declare it with var
