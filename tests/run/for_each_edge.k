// for x in s (#30), edge cases from review: a written type converts only
// x; s is evaluated once; array parameters; main's argv; compound literals
enum { four = 4 };
struct node { value:i32; next:node^; };
struct point { x:i32; y:i32; };

var calls = 0;
let row():i64 {
    calls += 1;
    return 1;
}

// a let array parameter has its declared length; a var one is a pointer
let sum4(xs:[i32](four)):i64 {
    var t:i64 = 0;
    for x in xs {
        t += x;
    }
    return t;
}

let sumn(n:i64, xs:[i32](n)):i64 {
    var t:i64 = 0;
    for x in xs {
        t += x;
    }
    return t;
}

let rest(var xs:[i32](2)):i64 {
    var t:i64 = 0;
    xs := xs.next;
    for x in xs {
        t += x;
    }
    return t;
}

let total(ps:[struct point](2)):i64 {
    var t:i64 = 0;
    for p in ps {
        t += p.x + p.y;
    }
    return t;
}

let main(argc:i32, argv:u8^^):i32 {
    // the elements are read as what they are, and x converts each
    var walked = 0;
    let bytes:[i32](3) = [300, 2, 0];
    for b:u8 in bytes {
        print(b, " ");
        walked += 1;
    }
    let wide:[i64](2) = [4294967297, 1];
    for w:i32 in wide {
        print(w, " ");
        walked += 1;
    }
    println(walked);

    // a row of a variable length array is evaluated once
    let n = 3;
    var m:[[i32](n)](2);
    m[1][0] = 4;
    m[1][1] = 5;
    m[1][2] = 6;
    var t = 0;
    for x in m[row()] {
        t += x;
    }
    println(t, " ", calls);

    var five:[i32](5) = [1, 2, 3, 4, 99];
    var ended:[i32](4) = [1, 2, 3, 0];
    var ps:[struct point](2) = [{1, 2}, {3, 4}];
    println(sum4(five), " ", sumn(2, five), " ", rest(ended), " ", total(ps));

    // main's argv, which C types char **
    var count = 0;
    for _ in argv {
        count += 1;
    }
    for _ in argv.next {
        count += 1;
    }
    println(count, " ", argc);

    // compound literals in the head
    walked = 0;
    for i in (i64){1}..<3 {
        print(i, " ");
        walked += 1;
    }
    for i in sizeof ([i32](2))[1, 2]..<10 {
        print(i, " ");
        walked += 1;
    }
    for x in ([i32](3))[5, 6, 7] {
        print(x, " ");
        walked += 1;
    }
    println(walked);

    // a list's loop variable may be written, as the node's pointer
    var n2:node = {2, nullptr};
    var n1:node = {1, &n2};
    walked = 0;
    for p:node^ in &n1 {
        print(p^.value, " ");
        walked += 1;
    }
    println(walked);
    return 0;
}
// out: 44 2 1 1 4
// out: 15 1
// out: 10 3 5 10
// out: 1 1
// out: 1 2 8 9 5 6 7 7
// out: 1 2 2
