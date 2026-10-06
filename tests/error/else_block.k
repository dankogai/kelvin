// error: expected '{' or 'if' after 'else': the body of 'else' is a block
let main():i32 {
    var n:i32 = 1;
    if n > 0 { n = 0; } else n = 1;
    return 0;
}
