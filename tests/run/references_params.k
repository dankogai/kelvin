// an array parameter is a pointer, as in C: reassign it with :=
sum(a: i32[4], n: i32): i32
{
    t: i32 = 0;
    end: i32^ := a + n;
    for (; a < end; a := a + 1)
        t += a^;
    return t;
}

main(argc: i32, argv: u8^[]): i32
{
    argv := argv + 1;
    xs: i32[4] = {1, 2, 3, 4};
    println(sum(xs, 4));
    return 0;
}
// out: 10
