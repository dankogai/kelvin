// error: assignment is a statement in Kelvin, not a value
main(): i32
{
    var a: i32 = 0, b: i32 = 0;
    a = b = 1;
    return 0;
}
