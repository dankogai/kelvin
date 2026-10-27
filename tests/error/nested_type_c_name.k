// shape.size is shape__size in C (#389): a type of that name is refused
struct shape__size { n:i64 }
struct shape { struct size { w:f64 }, s:size }
let main():i32 { return 0 }
// error: shape.size is shape__size in C, the name of a type declared already: rename one of them
