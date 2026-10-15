// a getter's self is a let (#137), const in C as any let (#27): it is
// read, borrowed as const T^, and copied into a var that may change
struct counter { n: i64; xs: Array<i64> }
let total(c:const counter^):i64 { c^.n + c^.xs.count as i64 }
extend counter {
    let sum:i64 { total(&self) }                         // a const borrow
    let next:i64 {
        var c = self.n                                   // a copy changes
        c += 1
        return c
    }
    var value:i64 {
        get { self.n }
        set(v) {                                         // the setter changes self
            self.n = v
            self.xs += v
        }
    }
}
let main():i32 {
    var c:counter = {1, $[]}
    c.value = 5
    c.value += 2
    println(c.sum, " ", c.next, " ", c.value, " ", c.xs)
    return 0
}
// out: 9 8 7 [5, 7]
// c: int64_t counter__sum(const struct counter self)
