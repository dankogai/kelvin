// .cstr is a property, read without parentheses, so it takes nothing (#53)
struct p { x: i64 }
let p.cstr(n:i64):cstr { `${n}` }
let main():i32 { return 0 }
// error: '.cstr' takes no parameters: it is a property, read as 'v.cstr'
