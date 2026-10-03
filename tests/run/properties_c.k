// for C structs, .size and .hex are fields: the field wins when unsure
#import "include/blob.h" as C
#import "include/bits.h" as C

main():i32 {
    var b:struct blob = make_blob();
    println(b.size, " ", b.hex, " ", b.size.dec);
    b.size = 9;
    println(make_blob().size, " ", b.size);
    // a bit-field is converted first: gcc's _Generic cannot see its type
    println(u32(bb.bf).hex, " ", i32(bb.sbf).dec);
    return 0;
}
// out: 5 6 5
// out: 5 9
// out: 0x7 -16
