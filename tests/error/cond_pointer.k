// error: a condition must be a bool, not u8^: compare it, as in 'p != nullptr'
let main():i32 {
    var p:u8^ := "text";
    while p {
        p := nullptr;
    }
    return 0;
}
