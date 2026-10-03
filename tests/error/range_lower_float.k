// error: a range is of integers, not f64
// both bounds are checked, not just the one whose type gives the counter
main():i32 {
    let x = 1.5;
    let n:i32 = 4;
    for i in x..<n {
    }
    return 0;
}
