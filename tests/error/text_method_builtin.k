// a built-in type's text is fixed (#53)
let i64.cstr():cstr { "n" }
let main():i32 { return 0 }
// error: a built-in type's text is fixed: '.cstr' may be defined for a struct or a union (#53)
