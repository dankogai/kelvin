// error: names starting with _kv_ are kelvinc's own, in the C it writes: rename '_kv_area'
struct point { x: i32 }
let point._kv_area():i32 { self.x }
let main():i32 { return 0 }
