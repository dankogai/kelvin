// a function defined inside a function (#180) sees globals and its own
// parameters, not the locals of the function around it: C has no closures
let main():int32 {
    var k:int64 = 3
    let addk(n:int64):int64 { n + k }
    println(addk(1))
    return 0
}
// error: a function defined inside a function cannot use 'k' of the function around it: C has no closures, so pass it as an argument, or make it a global
