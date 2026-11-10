// a converter of a struct is its attribute of that name (#512), which this
// one has not: it was C's error of a cast
struct point { x: i64; y: i64 }
let main():int32 {
    let p:point = {3, 4}
    println(i64(p))
    return 0
}
// error: i64(v) of point is its attribute '.i64', which it has not: define one, as in 'let i64:i64 { ... }'
