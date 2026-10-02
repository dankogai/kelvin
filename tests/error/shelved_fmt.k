// error: fmt() is shelved until Kelvin has a true string type
main(): i32
{
    var pi = 3.141592653589793;
    println(pi.fmt("%a"));
    return 0;
}
