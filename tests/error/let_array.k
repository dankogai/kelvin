// error: 'a' is a let and cannot change; declare it with var
main(): i32
{
    let a: i32[2] = {1, 2};
    a[0] = 3;
    return 0;
}
