let printf(fmt:const uint8^, ...):int32;

let main(argc:int32, argv:uint8^^):int32 {
    var name:uint8^ := argv[0];
    printf("%d %d\n", argc, name != 0);
    return 0;
}
// out: 1 1
