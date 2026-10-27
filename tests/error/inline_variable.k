// inline is for a function (#392), not a variable
inline let x = 3
let main():i32 { return 0 }
// error: 'inline' is for a function, a method or an operator
