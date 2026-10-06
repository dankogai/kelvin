// error: a condition must be a bool, not i32: compare it, as in 'x != 0'
// the operands of &&, || and ! are bool, too
let main():i32 {
    var n:i32 = 1;
    var ok:bool = true && !n;
    return 0;
}
