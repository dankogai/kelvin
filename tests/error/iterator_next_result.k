// an iterator's next gives an Optional, each value, then none (#318)
struct countdown { n: int64 }
var countdown.next():int64 { .n }
let main():int32 {
    var c:countdown = {3}
    for x in c { println(x) }
    return 0
}
// error: for walks an iterator by its next(), which takes nothing and gives each value, then none: write 'var countdown.next():T?'
