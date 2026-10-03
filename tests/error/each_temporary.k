// error: for over an array in a value that a call or '?:' returns
struct holder { xs:i32[3]; };
make():holder {
    let h:holder = {{7, 8, 0}};
    return h;
}
main():i32 {
    for x in make().xs {
        println(x);
    }
    return 0;
}
