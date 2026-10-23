// await waits for a Task (#312)
let main():int32 {
    let n:int64 = 3
    println(await n)
    return 0
}
// error: 'await' waits for a Task, which 'async f(x)' gives, and this is i64
