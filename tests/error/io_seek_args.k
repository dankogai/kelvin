// seek takes the offset from the start (#84)
let main():i32 {
    var f = IO.stdin
    f.seek()
    return 0
}
// error: '.seek' takes 1 argument
