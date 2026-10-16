// error: a condition must be a bool, not uintptr_t: compare it, as in 'x.addr != 0'
let main():int32 {
    var x:int32 = 1
    let p:int32^ := &x
    if p.addr {
        println("set")
    }
    return 0
}
