// x.sign (#382): -1, 0 or 1 of a signed integer's own type; of a
// floating-point number a bool? (#383), true by its sign bit's 0, false
// by its 1, zeros too, none of NaN; x.isNaN of a floating-point number
let main():int32 {
    let n:int64 = -3
    let z:int32 = 0
    let least:int64 = -9223372036854775807 - 1
    println(n.sign, " ", 5.sign, " ", z.sign, " ", (-5).sign, " ", (z - 9).sign, " ", least.sign, " ", n.abs * n.sign == n)
    let x:float64 = -2.5
    let f:float32 = 3.0
    let nz:float64 = -0.0
    println(x.sign, " ", f.sign, " ", 0.0.sign, " ", nz.sign, " ", nan.sign, " ", (-inf).sign, " ", x.sign ?? true)
    println(x.isNaN, " ", nan.isNaN, " ", (0.0 / 0.0).isNaN, " ", f.isNaN, " ", inf.isNaN, " ", !nan.isNaN)
    println(nan.sign ?? true, " ", nan.sign ?? false)
    return 0
}
// out: -1 1 0 -1 -1 -1 true
// out: some(false) some(true) some(true) some(false) none some(false) false
// out: false true true false false false
// out: true false
