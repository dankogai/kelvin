// error: would have the same C name, a___b, as another method
struct a_ { x:i32; };
struct a { y:i32; };
a_.b():i32 { return self.x; }
a._b():i32 { return self.y; }
