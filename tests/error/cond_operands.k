// error: a condition must be a bool, not i32: compare it, as in 'x != 0'
// the operands of &&, || and ! are bool, too
main(): i32
{
    n: i32 = 1;
    ok: bool = true && !n;
    return 0;
}
