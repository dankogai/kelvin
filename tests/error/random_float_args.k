// a floating-point type's random takes nothing, a limit, or a start and
// a limit (#547)
let main():int32 {
    println(f64.random(1.0, 2.0, 3.0))
    return 0
}
// error: f64.random takes nothing, a limit, or a start and a limit, as in 'f64.random(1.0, 2.0)'
