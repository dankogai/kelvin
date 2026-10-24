// and its next is a var method that gives an Optional (#319)
struct countdown { n: int64 }
let countdown.next():int64? { none }
let main():int32 {
    var c:countdown = {3}
    println(c.filter { $0 > 1 })
    return 0
}
// error: '.filter' walks an iterator by its next(), a var method that takes nothing and gives each value, then none: write 'var countdown.next():T?'
