// :() is no result, so the call gives nothing to hold (#141)
let f():() { println("f") }
let main():int32 {
    let v = f()
    return 0
}
// error: 'v' needs a type
