// error: pointer types are written with a postfix '^', as in 'i32^'
f(p: i32^): i32
{
    var q: i32* = p;
    return 0;
}
