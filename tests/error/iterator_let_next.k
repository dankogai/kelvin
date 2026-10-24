// an iterator's next changes it, so it is a var method (#318)
struct countdown { n: int64 }
let countdown.next():int64? { none }
let main():int32 {
    var c:countdown = {3}
    for x in c { println(x) }
    return 0
}
// error: 'countdown.next' is a let method, which reads it: write 'var countdown.next():T?'
