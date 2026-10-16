// a static let needs its value (#133)
struct rect { w: float64; h: float64 }
static let rect.unit:Self
let main():int32 { return 0 }
// error: a static let needs a value: write 'static let rect.unit = ...', or 'static var' if it changes
