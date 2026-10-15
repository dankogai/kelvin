// a .member on a new line goes on with the expression before it (#35),
// in a method too; one that sets a member starts a statement where
// there is self, since setting a member of what went before would mean
// nothing (#139)
struct bag { n: i64; xs: Array<i64> }
extend bag {
    let total():i64 {
        let k = .xs
            .count                                        // goes on: .xs.count
        return k as i64 + .n
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
    println(b.n, " ", b.xs, " ", b.total())
    return 0
}
// out: 9 [203, 4] 11
