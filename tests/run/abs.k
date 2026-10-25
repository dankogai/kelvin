// x.abs (#381): the magnitude of a signed integer or a floating-point
// number, of its type, with no import; a signed integer's least stays as
// it is, as two's complement negates it; arithmetic's too
struct p { abs: int64 }
let main():int32 {
    let n:int64 = -3
    let s:int32 = -300
    let least:int64 = -9223372036854775807 - 1
    let small:int32 = -2147483647 - 1
    println(n.abs, " ", s.abs, " ", least.abs, " ", small.abs, " ", (-5).abs, " ", 5.abs, " ", n.abs ** 2)
    let a:int32 = 3
    let b:int32 = 10
    println((a - b).abs, " ", (n * 2).abs + 1)
    let x:float64 = -2.5
    let f:float32 = -1.5
    println(x.abs, " ", f.abs, " ", (-0.0).abs, " ", (x - 1.0).abs, " ", 2.5.abs)
    let q:p = {-4}
    println(q.abs)
    return 0
}
// out: 3 300 -9223372036854775808 -2147483648 5 5 9
// out: 7 7
// out: 2.5 1.5 0.0 3.5 2.5
// out: -4
