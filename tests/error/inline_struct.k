// inline is for a function (#392), not a type
inline struct s { a:i64 }
let main():i32 { return 0 }
// error: 'inline' is for a function, a method or an operator: 'inline let f(...) { ... }'
