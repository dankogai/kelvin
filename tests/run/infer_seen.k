// a declaration infers its type from any value kelvinc sees (#47): a
// Kelvin function's or method's result, a variable, a field, p^, a[i],
// &x, a compound literal, a text property, a template, an enumerator, a
// character, sizeof, and a ?: between two values of one type
#import <complex.k>
struct point { x: i64; y: i64 }
enum color { RED, GREEN }
let mk(x:i64):point { (point){x, x * 2} }
let point.norm():i64 { self.x * self.x + self.y * self.y }
let main(argc:i32, argv:[u8^]):i32 {
    var i = complex64(0.0, 1.0)
    let p = mk(3)
    var q = p
    let n = p.norm()
    var x = p.x
    let r := &q
    var y = r^.y
    var ref := &q.y
    let arr:[i32](3) = [1, 2, 3]
    let a0 = arr[1]
    let ap := arr                     // an array is not copied: a pointer, to const for a let
    var k = i * 2.0                   // a struct's operator is a call, not C's arithmetic
    let c = argc > 1 ? 1:i32 : 2:i32
    let t := `${n}`
    let m = (point){4, 5}
    var f := mk
    let s := p.x.cstr
    let e = GREEN
    let ch = 'a'
    let sz = sizeof(point)
    let v = 4
    var cp := &v                      // &x of a let points to const
    println(i.real, " ", i.imag, " ", q.x, " ", n, " ", x, " ", y, " ", ref^)
    println(a0, " ", ap[2], " ", k.imag, " ", c, " ", t, " ", m.y, " ", f(1).y)
    println(s, " ", e, " ", ch, " ", sz, " ", cp^)
    println(i.typename, " ", p.typename, " ", r.typename, " ", ap.typename, " ", t.typename, " ", f.typename)
    println(c.typename, " ", e.typename, " ", ch.typename, " ", sz.typename, " ", ref.typename, " ", cp.typename)
    return 0
}
// out: 0.0 1.0 3 45 3 6 6
// out: 2 3 2.0 2 45 5 2
// out: 3 1 97 16 4
// out: complex64 point point^ const i32^ u8^ (i64):point
// out: i32 color u8 size_t i64^ const i64^
// c: struct complex64 i = complex64__f64__f64(0.0, 1.0);
// c: const int32_t *const ap = arr;
// c: const int64_t *cp = &v;
