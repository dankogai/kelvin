// alignas is for a variable or a member (#396), not a type's definition
alignas(16) struct s { a:i64 }
let main():i32 { return 0 }
// error: 'alignas' is for a variable or a member: 'alignas(16) var buf:[u8](64)'
