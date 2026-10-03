// bools infer bool (#25); assignment is a statement, there is no ++ or
// --, and pointers step with .next and .prev (#26)
struct node { value:i32; next:struct node^; };

positive(n:i32):bool { return n > 0; }

copy(var dst:u8^, var src:const u8^) {     // C: while ((*dst++ = *src++)) ;
    while src^ != 0 {
        dst^ = src^;
        dst := dst.next;
        src := src.next;
    }
    dst^ = 0;
}

main():i32 {
    var a = 1;
    var b = 2;
    var ok = a < b;                  // ok = (a < b): a bool
    var both = ok && positive(b);
    var no = !both;
    var same = ok;
    println(ok, " ", both, " ", no, " ", same, " ", sizeof(ok));

    var buf:u8[8];
    copy(buf, "kelvin");
    println(buf);

    var xs:i32[3] = {10, 20, 30};
    var p:i32^ := &xs[0];
    println(p.next^, " ", p.next.next^, " ", p.next.next.prev^, " ", (p.next - p) as i64);

    // a field named next is a field: n^.next
    var n3:struct node = {3, nullptr};
    var n2:struct node = {2, &n3};
    var total = 0;
    for (var n:struct node^ := &n2; n != nullptr; n := n^.next) total += n^.value;

    // for clauses and statements take comma lists of assignments
    for (var i = 0, j = 3; i < j; i += 1, j -= 1) total += i * j;
    var x:i32 = 0, y:i32 = 0;
    x = 1, y = x + 1;
    println(total, " ", x, " ", y);
    return 0;
}
// out: true true false true 1
// out: kelvin
// out: 20 30 20 1
// out: 7 1 2
