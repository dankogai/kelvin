// overloading (#41) on values only C sees, of each of C's types: a number
// goes to the overload of its Kelvin type, C's long and long long both
// i64 where they have 64 bits, char a u8; two C typedefs of one type
// (size_t and uintptr_t) each in a _Generic of their own
#import "include/ctypes.h" as C
#import <stdlib.h> as C

let kind(b:bool):cstr { "bool" }
let kind(n:i8):cstr { "i8" }
let kind(n:u8):cstr { "u8" }
let kind(n:i16):cstr { "i16" }
let kind(n:u16):cstr { "u16" }
let kind(n:i32):cstr { "i32" }
let kind(n:u32):cstr { "u32" }
let kind(n:i64):cstr { "i64" }
let kind(n:u64):cstr { "u64" }
let kind(x:f32):cstr { "f32" }
let kind(x:f64):cstr { "f64" }

let measure(n:size_t):cstr { "size_t" }
let measure(p:uintptr_t):cstr { "uintptr_t" }
let measure(x:f64):cstr { "f64" }

let main():i32 {
    println(kind(c_bool()), " ", kind(c_char()), " ", kind(c_schar()), " ", kind(c_uchar()), " ", kind(c_short()), " ",
            kind(c_ushort()), " ", kind(c_int()), " ", kind(c_uint()))
    println(kind(c_long()), " ", kind(c_ulong()), " ", kind(c_llong()), " ", kind(c_ullong()), " ", kind(c_float()), " ",
            kind(c_double()))
    println(measure(c_size()), " ", measure(atof("1.5")))
    return 0
}
// out: bool u8 i8 u8 i16 u16 i32 u32
// out: i64 u64 i64 u64 f32 f64
// out: size_t f64
