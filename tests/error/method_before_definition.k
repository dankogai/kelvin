// error: kv_no_such_method
struct point { x:i32; };
let main():i32 { var p:struct point = {1}; return p.area(); }
let point.area():i32 { return self.x; }
