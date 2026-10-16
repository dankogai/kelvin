// error: write 'p^.member' instead of 'p->member'
let f(p:int32^):int32 {
    var x:int32 = p->x;
    return 0;
}
