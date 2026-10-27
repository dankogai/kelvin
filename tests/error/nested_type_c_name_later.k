// shape.size is shape__size in C (#389), so a type of that name after it is refused
struct shape { struct size { w:f64 }, s:size }
struct shape__size { n:i64 }
let main():i32 { return 0 }
// error: shape.size is shape__size in C, the name of this type: rename one of them
