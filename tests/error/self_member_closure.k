// an anonymous function encloses nothing, self included (#32, #139)
struct point { x: int64; y: i64 }
let point.shift():i64 {
    let f:(i64):i64 := { (n:i64):i64 in n + .x }
    return f(1)
}
let main():i32 { return 0 }
// error: '.x' is self.x, and an anonymous function cannot use 'self' of the function around it
