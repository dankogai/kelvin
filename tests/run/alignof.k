// alignof(T) (#395), C23's name, as sizeof(T) is C's: C's _Alignof; and
// x.align, a value's type's alignment, as x.size is its size; both size_t
struct point { x:i32, y:f64 }
struct slot { align:i64 }
let main():i32 {
    let p:point = {1, 2.0}
    let b:u8 = 3
    var xs = [i16](4)
    let s:slot = {16}
    println(alignof(i64), " ", alignof(point), " ", alignof(u8^), " ", alignof([i32](3)))
    println(p.align, " ", b.align, " ", xs.align, " ", p.x.align, " ", alignof(point) == p.align, " ", s.align)
    static_assert(alignof(f64) == 8)
    println(`${alignof(i32)} and ${p.align}`)
    return 0
}
// out: 8 8 8 4
// out: 8 1 2 4 true 16
// out: 4 and 8
// c: _Alignof(int64_t)
// c: _Alignof(__typeof__(p))
