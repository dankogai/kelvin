// overloads differ in their parameter types, not only in their results (#41)
let half(n:int64):int64 { n / 2 }
let half(n:int64):float64 { float64(n) / 2.0 }
let main():int32 { return 0 }
// error: 'half' is declared with these parameter types already, with another result: overloads differ in their parameter types
