// error: ok(...) is a Result's case only where a Result is expected, as by a return of a function that gives one: elsewhere write Result<T, E>.ok(...) (#224)
let main():int32 {
    println(ok(5))
    return 0
}
