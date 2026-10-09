// Array<T> (#57): a growable array of T on the heap, an owner: made,
// grown, indexed (checked), walked, copied, moved by return and by
// passing, held by a struct, borrowed, nested, and freed by its block
struct point { x: i64; y: i64 }
struct bag { tag: i64; items: Array<i64> }
let squares(n:i64):Array<i64> {
    var xs = Array<i64>()
    for i in 0..<n { xs += i * i }
    return xs
}
let sum(xs:Array<i64>^):i64 { var s = 0; for x in xs^ { s += x }; return s }
let take(xs:Array<i64>):i64 { i64(xs.count) }
let main():i32 {
    var xs = squares(5)
    println(xs.count, " ", xs[4], " ", xs.typename, " ", xs.size, " ", sum(&xs))
    xs.insert(0, 100)
    xs.remove(1, 2)
    let last = xs.pop()
    println(xs.count, " ", xs[0], " ", last, " ", xs.capacity >= xs.count)
    let fixed:[i64](3) = [7, 8, 9]
    var ys = Array<i64>(fixed)
    ys += &xs
    ys.append(ys.copy())
    println(ys.count, " ", ys[3], " ", ys[ys.count - 1])
    var ps = Array<point>(2)
    ps[1] = (point){3, 4}
    ps += (point){5, 6}
    for p in ps { print(p.cstr, " ") }
    println()
    var b:bag = {1, Array<i64>()}
    b.items += 42
    println(b.items[0], " ", b.items.count)
    var m = Array<Array<i64>>()
    m += squares(3)
    m += squares(2)
    println(m.count, " ", m[0][2], " ", m[1].count, " ", m.typename)
    let n = take(xs)
    xs = Array<i64>(4)
    println(n, " ", xs.count, " ", xs[3])
    var cs = Array<cstr>()
    cs += "a"
    cs += "bc"
    for c in cs { print(c, "|") }
    println(" ", cs[1].count)
    return 0
}
// out: 5 16 Array<i64> 24 30
// out: 3 100 16 true
// out: 12 100 9
// out: {x: 0, y: 0} {x: 3, y: 4} {x: 5, y: 6} 
// out: 42 1
// out: 2 4 2 Array<Array<i64>>
// out: 3 4 0
// out: a|bc| 2
// c: KV_ARRAY(int64_t, _kv_array_i64, KV_PLAIN_FREE, KV_PLAIN_COPY)
// c: KV_ARRAY(_kv_array_i64, _kv_array_Array_i64, _kv_array_i64_free, _kv_array_i64_copy)
// c: __attribute__((cleanup(_kv_array_i64_free))) _kv_array_i64 xs = squares(5);
// c: return _kv_array_i64_take(&xs);
// c: (*_kv_array_i64_at(&xs, 4))
// c: _kv_array_i64_append_ref(&ys, &xs);
// c: int64_t n = take(_kv_array_i64_take(&xs));
