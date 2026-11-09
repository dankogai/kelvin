// a number has no members, where C's error said it is no struct (#497)
let main():int32 {
    let x = 1.5
    println(x.foo)
    return 0
}
// error: f64 has no member 'foo'
