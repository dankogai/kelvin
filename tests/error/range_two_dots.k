// error: expected '..<' or '...' in a range, as in '0..<n' or '1...n'
let main():i32 {
    var n = 3;
    for i in 0..n {
    }
    return 0;
}
