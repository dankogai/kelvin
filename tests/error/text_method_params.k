// .cstr is a property, read without parentheses, so it takes nothing (#53)
struct p { x: int64 }
let p.cstr(n:int64):cstr { `${n}` }
let main():int32 { return 0 }
// error: '.cstr' takes no parameters: it is a property, read as 'v.cstr'
