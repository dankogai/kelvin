// error: a condition must be a bool, not u8^: compare it, as in 'p != nowhere'
let main():int32 {
    var p:uint8^ := "text";
    while p {
        p := nowhere;
    }
    return 0;
}
