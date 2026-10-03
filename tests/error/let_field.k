// error: 'p' is a let and cannot change; declare it with var
struct point { x:i32; y:i32; };
main():i32 {
    let p:struct point = {1, 2};
    p.x = 3;
    return 0;
}
