// error: names starting with _kv_ are kelvinc's own, in the C it writes: rename '_kv_area'
struct point { x: int32 }
let point._kv_area():int32 { .x }
let main():int32 { return 0 }
