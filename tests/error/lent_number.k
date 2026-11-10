// lent is for an owner; a number is given as it is (#510)
let f(n:lent i64):i64 { n }
let main():int32 { return 0 }
// error: 'lent' is for an owner, a String, a Bytes, an Array, a Dictionary, a Set or a struct that owns: i64 is given as it is
