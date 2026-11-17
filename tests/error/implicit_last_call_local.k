// error: this value would be dropped: a body returns its value without 'return' only when it is one expression, so write 'return' before it
// the value of a call of an overloaded function is dropped at a body's
// end where the overload is chosen by a variable of the body's own
// (#594): of an f64 here, the one with a result
let note(x:int64) { println("note ", x) }
let note(x:float64):float64 { return x * 2.0 }
let half(x:float64):float64 {
    let y:float64 = x / 2.0
    note(y)
}
let main():int32 {
    println(half(1.0))
    return 0
}
