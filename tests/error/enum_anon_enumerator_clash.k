// a case of an enum with no tag is a word of the program: not an enumerator's name (#120)
enum { red; rgb: {r: u8, g: u8, b: u8} }
enum { red, blue }
let main():i32 { return 0 }
// error: 'red' is a case of enum{red, rgb: {r: u8, g: u8, b: u8}}, a word of the program: name the enumerator otherwise
