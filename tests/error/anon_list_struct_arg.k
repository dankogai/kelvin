// error: a list is not a value here: the parameter is struct point, so write a compound literal
struct point { x:i32; y:i32; };
show(p:point) { println(p.x); }
main():i32 {
    show({1, 2});
    return 0;
}
