// a method's self is a let (#138), const in C as any let (#27): it is
// read and borrowed as const T^, and a var copy of it changes
struct point { x: int64; y: i64 }
let norm1(p:const point^):i64 { (p^.x < 0 ? -p^.x : p^.x) + (p^.y < 0 ? -p^.y : p^.y) }
extend point {
    let moved(dx:i64):point {
        var p = self                                      // a copy changes
        p.x += dx
        return p
    }
    let size():i64 { norm1(&self) }                       // a const borrow
}
let main():i32 {
    let p:point = {1, -2}
    println(p.moved(3), " ", p, " ", p.size())
    return 0
}
// out: {x: 4, y: -2} {x: 1, y: -2} 3
// c: struct point point__moved(const struct point self, const int64_t dx)
