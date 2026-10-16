// an anonymous function encloses nothing, self included (#32, #139)
struct point { x: int64; y: int64 }
let point.shift():int64 {
    let f:(int64):int64 := { (n:int64):int64 in n + .x }
    return f(1)
}
let main():int32 { return 0 }
// error: '.x' is self.x, and an anonymous function cannot use 'self' of the function around it
