// an enumerator and a function of one name (#646): two kinds, one name
enum c { red, green }
let red():i64 { return 1 }
let main():int32 { return 0 }
// error: 'red' is a word of enum c already (line 2), and this is a function: a name at the top level names one thing, so name this one otherwise
