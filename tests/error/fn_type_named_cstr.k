// error: '.cstr' of a function: a function has no text
let add(a:i64):i64 { return a; }
let main():i32 {
    println(add.cstr);
    return 0;
}
