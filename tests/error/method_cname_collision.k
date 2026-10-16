// error: would have the same C name, a___b, as another method
struct a_ { x:int32; };
struct a { y:int32; };
let a_.b():int32 { return .x; }
let a._b():int32 { return .y; }
