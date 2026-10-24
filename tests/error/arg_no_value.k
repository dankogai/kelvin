// error: this has no value, so it cannot be argument 1 of 'println': make the call alone, as a line of its own
// a call of a function with no result is no argument (#316)
let tell(x:int64) { println(x) }
let main():int32 {
    println(tell(1))
    return 0
}
