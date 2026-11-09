// a member a struct does not have names its fields, where C's error
// named the C struct (#497)
struct Pt { x:i64; y:i64 }

let main():int32 {
    var pt:Pt
    println(pt.z)
    return 0
}
// error: Pt has no member 'z': its fields are x and y
