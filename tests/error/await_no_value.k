// a Task of a function without a result gives no value (#312)
let hello() { println("x") }
let main():int32 {
    let t = async hello()
    let v = await t
    return 0
}
// error: this Task has no value, as its function has no result: await it alone, as a line of its own
