// extend holds methods and attributes (#130)
struct rect { w: float64; h: float64 }
extend rect {
    struct inner { a: int64 }
}
let main():int32 { return 0 }
// error: extend holds let f() { }, static let f() { }, let x:R { }, var x:R { get { } set(v) { } }, static let x = v, static var x = v and static let +(a:T, b:T):T { }
