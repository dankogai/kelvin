// a union that holds itself (#659), where it was C's incomplete type
union u { x:i64; v:u }
let main():int32 { return 0 }
// error: 'v' makes u hold itself, and a value that holds itself has no size: hold it by a pointer, u^, or in an Array<u>
