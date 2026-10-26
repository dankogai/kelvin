// a parameter written `_` is unnamed (#388), as C's f(int): the function
// takes the argument and never reads it; `_` may stand for several, and
// an anonymous function's is still $0, $1, ...
struct counter { n:int64 }
let second(_:int64, y:int64):int64 { return y }
let last(_:int64, _:int64, z:int64):int64 { return z }
let hello(_:cstr) { println("hello") }
let skip(var _:int64, n:int64):int64 { return n }
let counter.add(_:cstr, k:int64):int64 { return self.n + k }
let main():int32 {
    println(second(1, 2), " ", last(1, 2, 3), " ", skip(4, 5))
    hello("ignored")
    let c:counter = {10}
    println(c.add("ignored", 5))
    let pick:(int64, int64):int64 := second
    println(pick(6, 7))
    let xs = $[3, 1, 2]
    println(xs.map { _ in 0 }, " ", xs.reduce(0) { acc, _ in acc + 1 })
    println(xs.map({ (_:int64):int64 in $0 * 10 }))
    let both:(int64, int64):int64 := { (_:int64, _:int64):int64 in $0 + $1 }
    println(both(8, 9))
    for _ in 0..<3 { print("x") }
    println()
    return 0
}
// out: 2 3 5
// out: hello
// out: 15
// out: 7
// out: [0, 0, 0] 3
// out: [30, 10, 20]
// out: 17
// out: xxx
// c: int64_t second(const int64_t _kv_arg0, const int64_t y)
// c: int64_t last(const int64_t _kv_arg0, const int64_t _kv_arg1, const int64_t z)
