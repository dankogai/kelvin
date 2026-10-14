// extend holds methods and attributes (#130)
struct rect { w: f64; h: f64 }
extend rect {
    struct inner { a: i64 }
}
let main():i32 { return 0 }
// error: extend holds let f() { }, static let f() { }, let x:R { }, var x:R { get { } set(v) { } }, static let x = v and static var x = v
