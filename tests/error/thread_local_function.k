// thread_local is of a variable; a function is every thread's (#641)
thread_local let twice(n:i64):i64 { n * 2 }
let main():int32 {
    println(twice(2))
    return 0
}
// error: 'thread_local' is of a variable, each thread's own: a function is every thread's already (#641)
