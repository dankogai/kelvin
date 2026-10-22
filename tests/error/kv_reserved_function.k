// kv_ names are the runtime's: a program's function of one would meet
// libkelvin's, so only kelvinc --runtime, building the runtime of
// runtime/*.k, names one so (#289)
let kv_string_trim(s:const String^):String { s^.copy() }
let main():int32 {
    return 0
}
// error: names starting with kv_ or KV_ are kelvinc's runtime's: rename 'kv_string_trim'
