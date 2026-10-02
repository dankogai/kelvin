// error: 'n' is a value (i32): assign it with '=', not ':='
x: i32 = 1;
struct inner { p: i32^; v: i32; };
struct inner;
main(): i32
{
    n: i32 = 1; k = 1, n := 5;
    return 0;
}
