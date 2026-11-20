// what #647 leaves as it was: a literal of as many values as members or
// elements, or fewer, the rest zero; a union of one value, or one named;
// a designator that goes back; a member array filled by its own [...]
struct p { x:i64; y:i64 }
union u { i:i64; f:f64 }
struct row { a:[i64](2); b:i64 }
let main():int32 {
    let q:p = {1, 2}
    let r:p = {7}
    let s:p = {.y = 5, .x = 4}
    let v:u = {3}
    let w:u = {.f = 1.5}
    var a:[i64](3) = [1, 2]
    let k:row = {[8, 9], 10}
    println(q.x + q.y, " ", r.y, " ", s.x, s.y, " ", v.i, " ", w.f, " ", a[2], " ", k.a[1] + k.b)
    return 0
}
// out: 3 0 45 3 1.5 0 19
