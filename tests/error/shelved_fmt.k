// error: fmt() is not a method: a value's text is 'x.cstr', and String(x.cstr) a String (#22, #55)
let main():i32 {
    var pi = 3.141592653589793;
    println(pi.fmt("%a"));
    return 0;
}
