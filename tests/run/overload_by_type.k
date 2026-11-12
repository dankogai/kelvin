// an overloaded function's name as a value is the overload of the
// function type written where it goes (#41): a declaration's, a global's,
// an assignment's target, a parameter's and a result's; kc picks it as
// kelvinc does (#537)
let over(n:i64):i64 { n + 1 }
let over(x:f64):f64 { x + 0.5 }
let over(a:i64, b:i64):i64 { a + b }
let apply(f:(i64):i64, n:i64):i64 { f(n) }
let applyf(f:(f64):f64, x:f64):f64 { f(x) }
let top:(i64):i64 := over
let pick():(i64):i64 { over }
let pick2():(i64, i64):i64 { return over }
let main():int32 {
    let h:(i64):i64 := over
    let hf:(f64):f64 := over
    let h2:(i64, i64):i64 := over
    var v:(f64):f64 := over
    v := over
    let via:((i64):i64, i64):i64 := apply
    println(h(1), " ", hf(1.0), " ", h2(1, 2), " ", v(2.0), " ", top(1))
    println(apply(over, 2), " ", applyf(over, 2.0), " ", apply(over, apply(over, 1)), " ", via(over, 5), " ", pick()(3), " ", pick2()(3, 4))
    return 0
}
// out: 2 1.5 3 2.5 2
// out: 3 2.5 3 6 4 7
