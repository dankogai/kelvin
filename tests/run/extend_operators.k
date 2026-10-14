// operators inside extend T { } (#135): static let +(a:T, b:T):T { },
// as Swift's static func +, the same as the top level's let +; with a
// number on one side, unary -, comparisons, and x += y by them (#42, #128)
struct money { cents: i64 }
extend money {
    static let +(a:money, b:money):money { (money){a.cents + b.cents} }
    static let *(a:money, k:i64):money { (money){a.cents * k} }
    static let -(a:money):money { (money){-a.cents} }
    static let <(a:money, b:money):bool { a.cents < b.cents }
    static let ==(a:money, b:money):bool { a.cents == b.cents }
    let dollars:f64 { self.cents / 100.0 }
}
enum maybe { none; some: i64 }
extend maybe {
    static let +(a:maybe, b:maybe):maybe {
        if a.is(some) && b.is(some) { return {.some = a.some + b.some} }
        return {.none}
    }
}
let main():i32 {
    let a:money = {150}
    var b:money = {275}
    b += a
    println((a + b * 2).cents, " ", (-a).cents, " ", a < b, " ", a == b, " ", b.dollars)
    var x = maybe.some(1)
    x += maybe.some(2)
    println(x)
    return 0
}
// out: 1000 -150 true false 4.25
// out: some(3)
// c: _kv_add_op__money__money(
