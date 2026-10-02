// error: expected '{': the body of 'do' is a block
main(): i32
{
    var n: i32 = 1;
    do n += 1; while n < 3;
    return 0;
}
