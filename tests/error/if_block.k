// error: the body of 'if' is a block: write 'if cond { ... }'
main(): i32
{
    var n: i32 = 1;
    if (n > 0) n = 0;
    return 0;
}
