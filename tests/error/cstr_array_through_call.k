// error: '.cstr' of an array: C arrays are not values
// kelvinc sees through p^ of a function's result, too
struct tag { n:i32; nm:u8[4]; };
var g:struct tag;
make():struct tag^ { return &g; }
main():i32 {
    println(make()^.nm.cstr);
    return 0;
}
