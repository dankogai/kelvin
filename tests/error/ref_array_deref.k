// error: this target is a reference (i32^): assign it with ':=', not '='
var x: i32 = 1;
struct inner { p: i32^; v: i32; };
struct inner;
main(): i32
{
    var refs: i32^[2] = {&x, &x}; refs^ = &x;
    return 0;
}
