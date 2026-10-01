// error: 'x' is not declared; a declaration cannot be the body of a statement or follow a label, so put it in a block
f(c: bool): i32
{
    if (c) x = 1;
    return 0;
}
