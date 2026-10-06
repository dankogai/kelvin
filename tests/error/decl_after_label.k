// error: a declaration cannot be the body of a statement or follow a label
let f(c:bool):i32 {
    again: var n:i32 = 0;
    return 0;
}
