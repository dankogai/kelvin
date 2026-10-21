// a struct with no tag (#59): {x:f64, y:f64} where a type goes, one C
// struct per spelling, so two written alike are one type; members,
// initializers, compound literals, text, parameters and results, nesting,
// arrays, pointers, Array<T> and owners as members
let norm(v:{x:float64, y:float64}):float64 { return v.x * v.x + v.y * v.y }
let origin():{x:float64, y:float64} {
    var o:{x:float64, y:float64} = {0.0, 0.0}
    return o
}
struct tagged { p: {x:float64, y:float64}; id: int32 }
let main():int32 {
    var v:{x:float64, y:float64} = {3.0, 4.0}
    println(v.x, " ", v.y, " ", norm(v), " ", v.typename)
    let w:{x:float64, y:float64} = v
    var a = ({x:float64, y:float64}){1.0, 2.0}
    println(`${a} ${w.x} ${origin()}`)
    var n:{p:{x:float64, y:float64}, tag:int32} = {{5.0, 6.0}, 7}
    println(n.p.y, " ", n.tag, " ", n.typename)
    var t:tagged = {v, 9}
    println(t.p.x, " ", t.id)
    var ps:[{x:float64, y:float64}](2)
    ps[1] = v
    println(ps[1].x, " ", ps.typename)
    var q:{x:float64, y:float64}^ := &v
    println(q^.y, " ", q.typename)
    var xs = Array<{x:float64, y:float64}>()
    xs += v
    println(xs[0].x, " ", xs.typename)
    var o:{b:Bytes, n:int32} = {Bytes("hi"), 2}
    println(o.b, " ", o.n, " ", o.typename)
    var m:{x:float64; y:float64} = {1.5, 2.5}
    println(m.cstr, " ", m.size)
    return 0
}
// out: 3.0 4.0 25.0 {x: f64, y: f64}
// out: {x: 1.0, y: 2.0} 3.0 {x: 0.0, y: 0.0}
// out: 6.0 7 {p: {x: f64, y: f64}, tag: i32}
// out: 3.0 9
// out: 3.0 [{x: f64, y: f64}](2)
// out: 4.0 {x: f64, y: f64}^
// out: 3.0 Array<{x: f64, y: f64}>
// out: hi 2 {b: Bytes, n: i32}
// out: {x: 1.5, y: 2.5} 16
// c: /* {x: f64, y: f64} */
// c: struct _kv_anon1
// c: double norm(const struct _kv_anon1 v)
// c: struct _kv_anon1 origin(void)
// c: KV_ARRAY(struct _kv_anon1, _kv_array_anon1, KV_PLAIN_FREE, KV_PLAIN_COPY)
// c: static inline void _kv__kv_anon3_free(struct _kv_anon3 *self)
