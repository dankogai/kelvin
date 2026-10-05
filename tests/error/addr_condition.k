// error: a condition must be a bool, not uintptr_t: compare it, as in 'x.addr != 0'
main():i32 {
    var x:i32 = 1
    let p:i32^ := &x
    if p.addr {
        println("set")
    }
    return 0
}
