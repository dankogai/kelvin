// a struct defines one type of a name (#389)
struct shape { struct size { w:f64 }, struct size { h:f64 }, s:size }
let main():i32 { return 0 }
// error: 'size' is defined in shape already
