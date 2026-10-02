// error: an any^ has no '.next': its element has no size
main(): i32
{
    p: any^;
    q: any^ := p.next;
    return 0;
}
