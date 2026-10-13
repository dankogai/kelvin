// a function of a type is declared on a type of the program (#111)
static let f64.zero():f64 { 0.0 }
let main():i32 { return 0 }
// error: a function of a type is declared on a struct, union or enum of the program: 'f64' is built in
