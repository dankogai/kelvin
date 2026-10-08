// a union cannot hold an owner (#54, O7)
union u { b: Bytes; n: i64 }
let main():i32 { return 0 }
// error: a union cannot hold an owner (#54): which member to free is unknown
