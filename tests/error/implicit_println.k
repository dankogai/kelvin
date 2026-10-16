// error: this has no value, but this function has a result, of type i64
let logged(x:int64):int64 { println(x) }
let main():int32 {
    println(logged(1))
    return 0
}
