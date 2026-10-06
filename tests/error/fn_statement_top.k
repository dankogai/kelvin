// a call at the top level is a statement, which goes in a function; only
// a name followed by parameters is told to take let (#45)
println("hi")
let main():i32 { return 0 }
// error: expected a declaration (let name(...):type, let or var name, struct, union, enum), found 'println': a statement goes in a function
