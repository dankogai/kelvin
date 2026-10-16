// error: an any^ has no '.next': its element has no size
let main():int32 {
    var p:any^;
    var q:any^ := p.next;
    return 0;
}
