// a union holds one member at a time, so a second value is an error
// (#647)
union u { i:i64; f:f64 }
let main():int32 {
    let x:u = {1, 2}
    println(x.i)
    return 0
}
// error: u holds one of its members at a time, and this gives a second value: write one, as in '{.f = v}'
