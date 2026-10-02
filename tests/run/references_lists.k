// declaration lists and globals with := (review of #19)
x: i32 = 7;
y: i32 = 1;
g := 0 as i32^;                     // a global reference, inferred
static h := 0 as i32^;

main(): i32
{
    g := &x;
    h := g;
    p: i32^ := &y;
    n: i32 = 7;
    // i is new and declared; p and n exist, so they are assigned
    for (i = 0, p := &x, n = 0; i < 3; i++)
        n = n + 1;
    println(g^, " ", h^, " ", p^, " ", n);
    k = 1, n = 40;                  // k is new, n is assigned
    println(k, " ", n);
    return 0;
}
// out: 7 7 7 3
// out: 1 40
