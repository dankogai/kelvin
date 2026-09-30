extern fn printf(fmt: *u8, ...) -> i32;

fn work(n: i32) -> i32 {
    defer printf("cleanup 1\n");
    defer {
        printf("cleanup 2\n");
    }
    if n > 0 {
        return n * 10;
    }
    printf("fallthrough\n");
    return 0;
}

fn main() {
    printf("got %d\n", work(1));
    printf("got %d\n", work(0));
    for i in 0..3 {
        defer printf("end of iteration %d\n", i);
        if i == 1 { continue; }
        if i == 2 { break; }
        printf("body %d\n", i);
    }
    {
        defer printf("inner scope\n");
    }
    printf("done\n");
}
// out: cleanup 2
// out: cleanup 1
// out: got 10
// out: fallthrough
// out: cleanup 2
// out: cleanup 1
// out: got 0
// out: body 0
// out: end of iteration 0
// out: end of iteration 1
// out: end of iteration 2
// out: inner scope
// out: done
