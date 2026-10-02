// error: expected '{' or 'if' after 'else': the body of 'else' is a block
main(): i32
{
    n: i32 = 1;
    if n > 0 { n = 0; } else n = 1;
    return 0;
}
