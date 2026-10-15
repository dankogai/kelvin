// a method reads self and never changes it (#138)
struct point { x: i64; y: i64 }
let point.moved(dx:i64):point {
    self.x += dx
    return self
}
let main():i32 { return 0 }
// error: a method reads self and never changes it
