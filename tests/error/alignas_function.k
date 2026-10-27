// alignas is for a variable or a member (#396): a function's alignment is C's
alignas(16) let f():i64 { return 1 }
let main():i32 { return 0 }
// error: 'alignas' is for a variable or a member: a function's alignment is the C compiler's
