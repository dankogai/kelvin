// error: some(v) makes no Optional: give v itself where a T? goes, which becomes some(v), or write Optional<T>(v)
let main():int32 {
    println(some(5))
    return 0
}
