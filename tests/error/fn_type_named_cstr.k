// error: '.cstr' of a function: a function has no text
add(a:i64):i64 { return a; }
main():i32 {
    println(add.cstr);
    return 0;
}
