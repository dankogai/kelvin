// error: Kelvin has no '--': write 'x -= 1' as a statement, or 'p := p.prev' for a pointer
main(): i32
{
    a: i32[2] = {1, 2};
    p: i32^ := &a[1];
    println(p--^);
    return 0;
}
