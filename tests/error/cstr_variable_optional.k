// a cstr variable where a String? goes is no String (#749): the case
// holds a String, and a template that is a cstr is one too
let main():int32 {
    let s:cstr := "a"
    var o:String? = `${s}b`
    return 0
}
// error: case 'some' of String? holds a String, and this is cstr
