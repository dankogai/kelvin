// a method of a type kelvinc sees that the type has not, and another has,
// is Kelvin's error (#539), where it was C's, of kv_no_such_method
// error: point has no method 'half': it is a method of 'f64'
struct point { x:int32; };
let float64.half():Self { return self / 2; }
let main():int32 { var p:struct point = {1}; return int32(p.half()); }
