// error: '.addr' is a property of pointers and functions
struct point { x: int32; y: int32 }
let main():int32 {
    let p:point = {1, 2}
    println(p.addr)
    return 0
}
