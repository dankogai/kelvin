// error: toString() is not a method: a value's text is 'x.cstr', and String(x.cstr) a String (#22, #55)
// #22: defining it is an error; the text of a value is .cstr (#53)
struct point { x:i32; };
let point.toString():cstr { return "point"; }
