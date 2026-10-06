// error: this never runs: in a function with no result, 'return' ends at the end of its line
let show(x:i64) {
    if x > 0 {
        return
            println("pos")
    }
    println("other")
}
let main():i32 {
    show(1)
    return 0
}
