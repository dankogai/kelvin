// error: Kelvin has no 'var': write 'x: T = ...', or 'x = ...' to infer the type
f(c: bool): i32
{
    var x: i32 = 0;
    return 0;
}
