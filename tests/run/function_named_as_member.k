// a function may be named by its types as a member of a type is (#575):
// meters(x:f64) and the attribute meters.f64 are both meters__f64 in C,
// which kelvinc refused, "would both be named meters__f64 in C: rename
// one"; the function is now _kv_fn_meters__f64 there, and both are. So
// with a method and a function of the type, with a prototype before the
// definition, and of a function given by its name as a value; two functions that share a C name are still an error
// (tests/error/overload_cname.k)
struct meters {
    value: f64
}
struct feet {
    value: f64
}
struct yards {
    value: f64
}
let meters(x:f64):meters                         // a prototype has the definition's name
let meters(n:i64):meters { (meters){n as f64} }
let meters(text:cstr):meters { (meters){f64(text)} }
let meters(f:feet):meters { (meters){f.value * 0.25} }
let meters(y:yards):meters { (meters){y.value * 0.5} }
extend meters {
    let f64:f64 { self.value }                   // an attribute, meters__f64 as meters(x:f64) was
    let i64:i64 { self.value as i64 }            // and meters__i64
    let feet():feet { (feet){self.value * 4.0} }          // a method, meters__feet
    static let yards():meters { meters((yards){100.0}) }     // a function of the type, meters__yards
}
let meters(x:f64):meters { (meters){x} }
let apply(f:(f64):meters, x:f64):meters { f(x) }
let main():int32 {
    let m = meters(1.5)
    let n = meters(2)
    let t = meters("2.5")
    println(m.f64, " ", n.f64, " ", n.i64, " ", t.f64, " ", meters((feet){10.0}).f64, " ", m.feet().value, " ", meters.yards().f64)
    println( apply(meters, 7.5).f64, " ", meters(m.f64 + n.f64).i64, " ", meters(meters(3).i64).f64)
    return 0
}
// out: 1.5 2.0 2 2.5 2.5 6.0 50.0
// out: 7.5 3 3.0
