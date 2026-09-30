extern fn printf(fmt: *u8, ...) -> i32;

fn main(argc: i32, argv: **u8) -> i32 {
    printf("argc=%d\n", argc);
    return argc - 1;
}
// out: argc=1
