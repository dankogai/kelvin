// error: toString() is shelved until Kelvin has a true string type
// #22: defining it waits for a true string type, too
struct point { x:i32; };
point.toString():cstr { return "point"; }
