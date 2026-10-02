// error: '.cstr' of an array: C arrays are not values
main(): i32
{
    a: i32[3] = {1, 2, 3};
    println(a.cstr);
    return 0;
}
