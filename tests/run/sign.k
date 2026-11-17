// x.sign (#382): -1, 0 or 1 of a signed integer's own type; of a
// floating-point number -1 or 1, an i64, by its sign bit (#597), 1 by its
// 0 and -1 by its 1, zeros and NaN too; x.isNaN of a floating-point number
let main():int32 {
    let n:int64 = -3
    let z:int32 = 0
    let least:int64 = -9223372036854775807 - 1
    println(n.sign, " ", 5.sign, " ", z.sign, " ", (-5).sign, " ", (z - 9).sign, " ", least.sign, " ", n.abs * n.sign == n)
    let x:float64 = -2.5
    let f:float32 = 3.0
    let nz:float64 = -0.0
    println(x.sign, " ", f.sign, " ", 0.0.sign, " ", nz.sign, " ", nan.sign, " ", (-inf).sign, " ", x.sign < 0)
    println(x.isNaN, " ", nan.isNaN, " ", (0.0 / 0.0).isNaN, " ", f.isNaN, " ", inf.isNaN, " ", !nan.isNaN)
    println((-nan).sign, " ", x.abs * x.sign as f64 == x, " ", x.sign.typename, " ", f.sign.typename)
    return 0
}
// out: -1 1 0 -1 -1 -1 true
// out: -1 1 1 -1 1 -1 true
// out: false true true false false false
// out: -1 true i64 i64
