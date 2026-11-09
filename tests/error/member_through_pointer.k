// a member through a pointer is p^.x, where C's error said '->' (#497)
struct Pt { x:i64 }

let main():int32 {
    var pt:Pt
    var q:Pt^ := &pt
    println(q.x)
    return 0
}
// error: '.x' of struct Pt^, a pointer: its member is 'q^.x'
