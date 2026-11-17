// error: this value would be dropped: a body returns its value without 'return' only when it is one expression, so write 'return' before it
// the value of a method of a variable of the body's own is dropped at
// its end too: its receiver's type is that of a local (#594), here of a
// struct and, by math's abs, of an f64
struct box { n:int64 }
let box.twice():int64 { return .n * 2 }
let size(x:float64):float64 {
    let y:float64 = x - 1.0
    y.abs()
}
let last(n:int64):int64 {
    let b:box = {n}
    b.twice()
}
let main():int32 {
    println(size(0.5), " ", last(1))
    return 0
}
