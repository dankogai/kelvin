printf(fmt: const u8^, ...): i32;

main(argc: i32, argv: u8^^): i32
{
    var name: u8^ := argv[0];
    printf("%d %d\n", argc, name != 0);
    return 0;
}
// out: 1 1
