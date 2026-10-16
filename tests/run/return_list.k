// return {...} (#77): the list takes the function's result type, as a
// declaration's does: a struct, with designators, a union, a C struct,
// an enum with values' {.n = v}, and the value of a Result or an
// Optional, wrapped
#import <time.h> as C
struct point { x: int32; y: int32 }
union num { i: int32; f: float32 }
enum json { n: float64; s: cstr }
struct timespec;
let origin():point { return {0, 0} }
let corner():point { return {.y = 7} }
let asInt(v:int32):num { return {.i = v} }
let half():json { return {.n = 0.5} }
let moment():timespec { return {1, 2} }
let maybe(ok:bool):point? {
    if !ok { return none }
    return {3, 4}
}
let res(ok:bool):Result<point, cstr> {
    if !ok { return err("no") }
    return {5, 6}
}
let one():Result<int64, cstr> { return {1} }
let main():int32 {
    let o = origin()
    let c = corner()
    let u = asInt(9)
    let j = half()
    let t = moment()
    println(o.cstr, " ", c.cstr, " ", u.i, " ", j.cstr, " ", t.tv_sec, " ", t.tv_nsec)
    var m1 = maybe(true)
    var m2 = maybe(false)
    var r1 = res(true)
    var r2 = res(false)
    var w = one()
    println(m1.cstr, " ", m2.cstr, " ", r1.cstr, " ", r2.cstr, " ", w.ok)
    return 0
}
// out: {x: 0, y: 0} {x: 0, y: 7} 9 n(0.5) 1 2
// out: some({x: 3, y: 4}) none ok({x: 5, y: 6}) err("no") 1
// c: return (struct point){0, 0};
// c: return _kv__kv_res_point_cstr_make_ok((struct point){5, 6});
