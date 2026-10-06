// error: 'p^.type' is any, which exists only as 'any^', C's void *
let main():i32 {
    var x:i32 = 1;
    var p:any^ := &x;
    var q:p^.type;
    return 0;
}
