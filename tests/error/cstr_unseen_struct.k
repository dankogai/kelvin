// error: kv_cstr_unseen_struct
// kelvinc cannot see that this value is a struct, so it has no buffer
// sized for its text: assign it to a variable first
struct point { x:int32; y:int32; };
let main():int32 {
    var p:struct point = {1, 2};
    var q:struct point = {3, 4};
    println((q, p).cstr);
    return 0;
}
