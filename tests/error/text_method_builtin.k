// a built-in type's text is fixed (#53)
let int64.cstr():cstr { "n" }
let main():int32 { return 0 }
// error: a built-in type's text is fixed: '.cstr' may be defined for a struct or a union (#53)
