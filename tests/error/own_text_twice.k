// a type gives its own text once, by .string or by .cstr() (#506)
struct v2 { x: f64; y: f64 }
let v2.cstr():cstr { `(${.x}, ${.y})` }
let v2.string:String { $`<${.x}, ${.y}>` }
let main():int32 { return 0 }
// error: struct v2 has its own text already, '.cstr()': a type gives its text once, by '.string' or by '.cstr()'
