// var T.m(...) (#318): a method whose self is the caller's var, which it
// changes, as a var attribute's setter does; a let method reads self and
// never changes it (#138)
struct counter { n: int64 }
var counter.bump(by:int64):int64 {
    .n += by
    return .n
}
extend counter {
    var reset() { self.n = 0 }
    var twice() { .bump(.n) }                    // a var method calls another on self
    let doubled():int64 { .n * 2 }
}
struct pair { a: counter; b: counter }
let grow(c:counter^) { c^.bump(10) }             // through a borrow
let main():int32 {
    var c:counter = {1}
    let first = c.bump(2)
    let second = c.bump(3)
    println(first, " ", second, " ", c.n, " ", c.doubled())
    c.twice()
    println(c.n)
    c.reset()
    println(c.n)
    var p:pair = {{10}, {20}}
    p.a.bump(1)
    grow(&p.b)
    var cs:[counter](2) = [{1}, {2}]
    cs[1].bump(5)
    println(p.a.n, " ", p.b.n, " ", cs[0].n, " ", cs[1].n)
    return 0
}
// out: 3 6 6 12
// out: 12
// out: 0
// out: 11 30 1 7
