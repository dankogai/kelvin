// error: this has no value, but this function has a result, of type i64
let log(x:int64) { println("log ", x) }
let f(x:int64):int64 { log(x) }
let main():int32 {
    println(f(1))
    return 0
}
