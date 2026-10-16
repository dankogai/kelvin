// error: expected '{': the body of 'do' is a block
let main():int32 {
    var n:int32 = 1;
    do n += 1; while n < 3;
    return 0;
}
