// error: expected '{': the body of 'do' is a block
main(): i32
{
    n: i32 = 1;
    do n++; while n < 3;
    return 0;
}
