// restrict qualifies a pointer alone (#393), as in C
let f(n:i64 restrict):() { }
let main():i32 { return 0 }
// error: 'restrict' is a pointer's: write it after the ^, as in 'u8^ restrict'
