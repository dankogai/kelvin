// error: kv_cstr_unseen_struct
// kelvinc cannot see that this value is a struct, so it has no buffer
// sized for its text: assign it to a variable first
struct point { x:i32; y:i32; };
main():i32 {
    var p:struct point = {1, 2};
    var q:struct point = {3, 4};
    var c:bool = true;
    println((c ? p : q).cstr);
    return 0;
}
