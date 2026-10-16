// error: kv_no_such_method
struct point { x:int32; };
let main():int32 { var p:struct point = {1}; return p.area(); }
let point.area():int32 { return .x; }
