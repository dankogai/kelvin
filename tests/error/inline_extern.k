// an extern function is defined elsewhere, so it is not inline (#392)
extern inline let f(x:i64):i64
let main():i32 { return 0 }
// error: an extern function is defined elsewhere: 'inline' is for one defined here
