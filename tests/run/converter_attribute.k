// a converter of a struct is its attribute of that name (#512), as i64(s)
// and s.i64 of text are one: i64(b), u64(b) and f64(b) of a BigInt are
// b.i64, b.u64 and b.f64; a value an expression gives is held and freed
struct money { cents: i64 }
extend money {
    let i64:i64 { self.cents / 100 }
    let f64:f64 { (self.cents as f64) / 100.0 }
}
let main():int32 {
    let m:money = {1234}
    println(m.i64, " ", i64(m), " ", f64(m), " ", f64((money){50}))
    let bi = 12345678901234567890123n
    println(f64(bi), " ", i64(bi), " ", u64(bi), " ", i64(-5n), " ", f64(bi * 2) == (bi * 2).f64, " ", bi)
    return 0
}
// out: 12 12 12.34 0.5
// out: 1.2345678901234568e+22 4807115922877859019 4807115922877859019 -5 true 12345678901234567890123n
