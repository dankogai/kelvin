// error: an any^ has no '.next': its element has no size
main(): i32
{
    var p: any^;
    var q: any^ := p.next;
    return 0;
}
