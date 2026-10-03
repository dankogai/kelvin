// error: a declaration cannot be the body of a statement or follow a label
f(c:bool):i32 {
    for (; c;) var x = 1;
    return 0;
}
