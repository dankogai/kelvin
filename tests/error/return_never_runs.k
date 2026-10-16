// error: this never runs: in a function with no result, 'return' ends at the end of its line
let show(x:int64) {
    if x > 0 {
        return
            println("pos")
    }
    println("other")
}
let main():int32 {
    show(1)
    return 0
}
