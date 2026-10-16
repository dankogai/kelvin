// error: a declaration cannot be the body of a statement or follow a label
let f(c:bool):int32 {
    for (; c;) var x = 1;
    return 0;
}
