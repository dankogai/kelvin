// error: this has no value, but this function has a result, of type i64: write 'return' with a value after it
// a call of a function with no result is no value where its name is
// overloaded too (#593): the program's own log, beside math's
let log(x:int64) { println("log ", x) }
let f(x:int64):int64 { log(x) }
let main():int32 {
    println(f(1))
    return 0
}
