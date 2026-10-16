// a case of an enum with no tag is a word of the program: not a function's name (#120)
enum { red; rgb: {r: uint8, g: uint8, b: uint8} }
let red():int32 { 1 }
let main():int32 { return 0 }
// error: 'red' is a case of enum{red, rgb: {r: u8, g: u8, b: u8}}, a word of the program: name the function otherwise
