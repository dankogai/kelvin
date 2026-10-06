// error: a condition must be a bool, not i32: compare it, as in 'x != 0'
let main():i32 {
    var n:i32 = 1;
    if n {
        n = 0;
    }
    return 0;
}
