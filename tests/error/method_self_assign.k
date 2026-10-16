// .x is self.x (#139), which a method never changes (#138)
struct point { x: int64; y: i64 }
let point.reset() {
    .x = 0
}
let main():i32 { return 0 }
// error: a method reads self and never changes it
