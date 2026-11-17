// error: this value would be dropped: a body returns its value without 'return' only when it is one expression, so write 'return' before it
// the value of a call of an overloaded function is dropped at a body's
// end as that of any function is (#593)
let twice(x:int64):int64 { return x * 2 }
let twice(x:float64):float64 { return x * 2.0 }
let f(x:int64):int64 { if x > 0 { twice(x) } else { twice(-x) } }
let main():int32 {
    println(f(1))
    return 0
}
