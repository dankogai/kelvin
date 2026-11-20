// an enumerator of two enums (#646): each is a word of the program, as
// in C
enum c { red, green }
enum d { red, blue }
let main():int32 { return 0 }
// error: 'red' is a word of enum c already (line 3), and this is a word of enum d: a name at the top level names one thing, so name this one otherwise
