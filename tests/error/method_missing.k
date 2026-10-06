// error: kv_no_such_method
struct point { x:i32; };
let f64.half():f64 { return self / 2; }
let main():i32 { var p:struct point = {1}; return i32(p.half()); }
