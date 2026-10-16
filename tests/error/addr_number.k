// error: '.addr' is a property of pointers and functions
let main():i32 {
    let n:int64 = 1
    println(n.addr)
    return 0
}
