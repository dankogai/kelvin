// error: '.cstr' of an array: C arrays are not values
let main():i32 {
    var a:i32[3] = {1, 2, 3};
    println(a.cstr);
    return 0;
}
