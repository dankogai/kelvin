// extern goes before let, as for a variable (#45)
extern labs(n:i64):i64
let main():i32 { return 0 }
// error: a function is declared with let: write 'extern let labs(...)'
