// $(...) (#181) calls the function it is written in: one at the top level,
// one inside a function, an anonymous one, and a function of a type
struct counter { n: int64 }
extend counter {
    static let countdown(n:int64):int64 { n <= 0 ? 0 : n + $(n - 1) }
}
let fib(n:int64):int64 { n < 2 ? n : $(n - 2) + $(n - 1) }
let main():int32 {
    let fact(n:int64):int64 { n < 2 ? 1 : n * $(n - 1) }
    let gcd:(int64, int64):int64 := { (a:int64, b:int64):int64 in b == 0 ? a : $(b, a % b) }
    var xs = $[3, 1, 2]
    let sum(xs:$[int64]^, i:int64):int64 { i >= xs^.count as int64 ? 0 : xs^[i] + $(xs, i + 1) }
    println(fib(10), " ", fact(5), " ", gcd(48, 18), " ", sum(&xs, 0), " ", counter.countdown(4))
    return 0
}
// out: 55 120 6 6 10
