// error: '.addr' is a property of pointers and functions
struct point { x: i32; y: i32 }
let main():i32 {
    let p:point = {1, 2}
    println(p.addr)
    return 0
}
