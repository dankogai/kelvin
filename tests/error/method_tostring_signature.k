// error: toString must be declared as 'point.toString(): String'
struct point { x: i32; };
point.toString(k: i32): String { return "x".toString(); }
