// a top-level let of a pointer is a const pointer, as a local's (#27):
// what it points to may change, through q^, and the pointer may not;
// kc writes const after the *, as kelvinc does (#680)
var x = 1
let q:int64^ := &x
let p := "text"
let s:cstr := "more"
let main():int32 {
    q^ = 5
    q^ += 1
    println(x, " ", q^, " ", p, " ", s, " ", p.count)
    return 0
}
// out: 6 6 text more 4
