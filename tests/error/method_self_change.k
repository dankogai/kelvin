// a method reads self and never changes it (#138)
struct point { x: int64; y: int64 }
let point.moved(dx:int64):Self {
    .x += dx
    return self
}
let main():int32 { return 0 }
// error: a method reads self and never changes it
