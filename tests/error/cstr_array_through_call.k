// error: '.cstr' of an array: C arrays are not values
// kelvinc sees through p^ of a function's result, too
struct tag { n:int32; nm:[uint8](4); };
var g:struct tag;
let make():struct tag^ { return &g; }
let main():int32 {
    println(make()^.nm.cstr);
    return 0;
}
