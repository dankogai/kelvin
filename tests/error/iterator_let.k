// for walks an iterator by its var next(), which changes it (#318)
struct countdown { n: int64 }
var countdown.next():int64? { if .n == 0 { return none }; .n -= 1; return .n + 1 }
let main():int32 {
    let c:countdown = {3}
    for x in c { println(x) }
    return 0
}
// error: for walks an iterator by its var next(), which changes 'c', a let: declare it with var
