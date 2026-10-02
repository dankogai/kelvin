// for C structs, .size and .hex are fields: the field wins when unsure
#import "include/blob.h" as C

main(): i32
{
    b: struct blob = make_blob();
    println(b.size, " ", b.hex, " ", b.size.dec);
    b.size = 9;
    println(make_blob().size, " ", b.size);
    return 0;
}
// out: 5 6 5
// out: 5 9
