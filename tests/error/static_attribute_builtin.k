// error: a computed attribute of a type is declared on a struct, union or enum of the program, on Bytes or String, or on an integer type: of 'f64', which is built in, write a stored one, 'static let f64.half = ...'
// a built-in number type has stored attributes of the type alone (#595), as it has no functions of the type
extend f64 { static let half:Self { 0.5 } }
let main():int32 { return 0 }
