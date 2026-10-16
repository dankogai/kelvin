// a getter's self is a let (#137), const in C as any let (#27): it is
// read, borrowed as const T^, and copied into a var that may change
struct counter { n: int64; xs: Array<int64> }
let total(c:const counter^):int64 { c^.n + c^.xs.count as int64 }
extend counter {
    let sum:int64 { total(&self) }                         // a const borrow
    let next:int64 {
        var c = self.n                                   // a copy changes
        c += 1
        return c
    }
    var value:int64 {
        get { self.n }
        set(v) {                                         // the setter changes self
            self.n = v
            self.xs += v
        }
    }
}
let main():int32 {
    var c:counter = {1, $[]}
    c.value = 5
    c.value += 2
    println(c.sum, " ", c.next, " ", c.value, " ", c.xs)
    return 0
}
// out: 9 8 7 [5, 7]
// c: int64_t counter__sum(const struct counter self)
