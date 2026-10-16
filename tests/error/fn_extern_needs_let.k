// extern goes before let, as for a variable (#45)
extern labs(n:int64):int64
let main():int32 { return 0 }
// error: a function is declared with let: write 'extern let labs(...)'
