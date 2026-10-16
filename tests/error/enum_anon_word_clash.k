// a case of an enum with no tag is a word of the program: not ok, err, none or some (#120)
enum { none; some: int32 }
let main():int32 { return 0 }
// error: 'none' is a word of Result and Optional (#72, #75): a case of an enum with no tag is a word of the program
