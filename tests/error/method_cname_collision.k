// error: would have the same C name, a___b, as another method
struct a_ { x:i32; };
struct a { y:i32; };
let a_.b():i32 { return self.x; }
let a._b():i32 { return self.y; }
