// restrict is a pointer's own (#393): it follows the ^, as `u8^ const` does
let f(p:restrict u8^):() { }
let main():i32 { return 0 }
// error: 'restrict' is a pointer's: write it after the ^, as in 'u8^ restrict'
