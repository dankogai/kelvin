// a Task has no text: its value has (#312)
let one():int64 { 1 }
let main():int32 {
    let t = async one()
    println(t)
    return 0
}
// error: a Task has no text: print its value, 'await t'
