// error: kv_no_such_method
struct point { x:int32; };
let float64.half():Self { return self / 2; }
let main():int32 { var p:struct point = {1}; return int32(p.half()); }
