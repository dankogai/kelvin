// a cstr parameter of async f(x) would share text with its thread (#312)
let len(c:cstr):int64 { 1 }
let main():int32 {
    let t = async len("x")
    return 0
}
// error: 'async' would share this text with the call's thread: the parameter is a cstr, where a String would move in
