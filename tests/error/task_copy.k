// a Task is an owner that is not copied (#312)
let one():int64 { 1 }
let main():int32 {
    let t = async one()
    let u = t
    return 0
}
// error: a Task is not copied: pass it on, or await it
