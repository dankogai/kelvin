// error: a condition must be a bool, not i32: compare it, as in 'x != 0'
// the operands of &&, || and ! are bool, too
let main():int32 {
    var n:int32 = 1;
    var ok:bool = true && !n;
    return 0;
}
