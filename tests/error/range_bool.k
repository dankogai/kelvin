// a range is of integers, and a bool is none (#373)
let main():int32 {
    let r = 0...true
    return 0
}
// error: a range is of integers, not bool
