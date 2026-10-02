// error: 'b' needs a type: write
// true and false infer bool (#24), but other bool values do not
main(): i32
{
    t = true;
    b = 1 < 2;
    return 0;
}
