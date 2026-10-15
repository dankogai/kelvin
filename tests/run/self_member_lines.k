// where there is self, a line that starts with .x is self.x, a statement
// of its own (#139, #142), where a .member on a new line went on with the
// expression before it (#35); a chain over several lines goes inside
// parentheses there, and #35 holds where there is no self
struct bag { n: i64; xs: Array<i64> }
enum { nothing; just: i64 }
extend enum{nothing, just: i64} {
    let orTen():i64 {
        let k = 10
        return .is(just) ? .just + k : k                  // a statement: self.is(just)
    }
}
extend bag {
    let total():i64 {
        let k = (.xs
            .count)                                       // in parentheses: .xs.count
        return k as i64 + .n
    }
    let bump(p:i64^):() { p^ += 100 }
    let first():i64 {
        var k = .n
        .bump(&k)                                         // a statement too: self.bump(&k)
        return k
    }
    var count:i64 {
        get { .n }
        set(v) {
            .n = v * 2
            .xs += v                                      // a statement
            .xs[0] += 100                                 // a statement
            .n += 1                                       // a statement
        }
    }
}
let main():i32 {
    var b:bag = {0, $[]}
    b.count = 3
    b.count = 4
    let j = just(5)
    var n = nothing
    println(b.n, " ", b.xs, " ", b.total(), " ", b.first(), " ", j.orTen(), " ", n.orTen())
    let q = b
        .total()                                          // no self here: #35, b.total()
    println(q)
    return 0
}
// out: 9 [203, 4] 11 109 15 10
// out: 11
