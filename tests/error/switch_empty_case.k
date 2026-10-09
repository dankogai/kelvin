// a case ends at the next, so an empty one before another is a mistake (#63)
let main():i32 {
    var n:i32 = 1
    switch n {
    case 1:
    case 2:
        println(1)
    default:
        break
    }
    return 0
}
// error: a case ends at the next case, and the one before this has no body: write 'case a, b:' to share a body, or 'break' to do nothing
