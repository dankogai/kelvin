// error: the body of 'if' is a block: write 'if cond { ... }'
let main():int32 {
    var n:int32 = 1;
    if (n > 0) n = 0;
    return 0;
}
