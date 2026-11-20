// an enumerator and a global of one name (#646)
enum c { red, green }
var red:i64 = 1
let main():int32 { return 0 }
// error: 'red' is a word of enum c already (line 2), and this is a global: a name at the top level names one thing, so name this one otherwise
