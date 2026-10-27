// a function type is no object's pointer, which restrict is for (#393), as in C
var g:(i64):i64 restrict
let main():i32 { return 0 }
// error: 'restrict' is a pointer's: write it after the ^, as in 'u8^ restrict'
