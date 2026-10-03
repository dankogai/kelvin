// error: kv_no_such_method
struct point { x:i32; };
f64.half():f64 { return self / 2; }
main():i32 { var p:struct point = {1}; return i32(p.half()); }
