// error: write 'p^.member' instead of 'p->member'
f(p: i32^): i32
{
    var x: i32 = p->x;
    return 0;
}
