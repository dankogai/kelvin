// a function of a type is declared on a type of the program (#111)
static let float64.zero():Self { 0.0 }
let main():int32 { return 0 }
// error: a function of a type is declared on a struct, union or enum of the program, or on Bytes or String: 'f64' is built in
