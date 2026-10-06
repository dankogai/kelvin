// a parameter is C's pointer, so its count is not known there (#49)
let sum(a:[i64]):i64 {
    var s = 0
    for i in 0..<a.count { s += a[i] }
    return s
}
let main():i32 { return 0 }
// error: '.count' is a property of arrays, and this is i64^, a pointer: an array passed to a function is one, so its count is passed beside it
