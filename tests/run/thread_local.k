// thread_local var x is each thread's own (#641), C's _Thread_local: two
// Tasks count their own hits from 0, and main's are untouched; in a block
// it is static, each thread's own as well
thread_local var hits:i64 = 0
let work(n:i64):i64 {
    for _ in 0..<n { hits += 1 }
    return hits
}
let count():i64 {
    thread_local var calls:i64 = 0
    calls += 1
    return calls
}
let main():int32 {
    let a = async work(3)
    let b = async work(5)
    println(await a, " ", await b, " ", hits, " ", count(), " ", count())
    return 0
}
// out: 3 5 0 1 2
