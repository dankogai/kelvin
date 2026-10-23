// a Task<T> is of its function's result (#312)
let fib(n:int64):int64 { n }
let main():int32 {
    let t:Task<f64> = async fib(3)
    return 0
}
// error: this call gives Task<i64>, and Task<f64> is wanted here
