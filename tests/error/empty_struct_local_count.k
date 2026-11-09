// An array of empty structs counts by its declared length, which C's sizeof
// cannot give, so that length is a constant, not a local's (#499)
struct none { }
let f(n: i64):i64 {
    var a: [none](n)
    return a.count
}
let main():int32 { return f(3) as i32 }
// error: an array of struct none, whose elements have no size, takes a constant length: its count is the length, which C's sizeof cannot give, and this one names a local
