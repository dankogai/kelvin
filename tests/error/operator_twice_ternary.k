// x op= y is x = x op y, so x may not hold a call, also in ?: (#42)
struct vec { x: float64; y: float64 }
let *(a:vec, k:float64):vec { (vec){a.x * k, a.y * k} }
var n:int64 = 0
let next():int64 {
    n += 1
    return n
}
let main():int32 {
    var vs:[struct vec](3) = [{1.0, 1.0}, {2.0, 2.0}, {3.0, 3.0}]
    vs[n > 0 ? next() : 0] *= 2.0
    return 0
}
// error: with an operator a struct defines, 'x *= y' is 'x = x * y', which evaluates x twice, so x may not hold a call
