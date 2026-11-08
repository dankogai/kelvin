// a method's overload declared after a call is not seen there either (#492)
struct Box { n: i64 }
extend Box {
    var put(s:const String^) { self.put(s^.cstr) }
    var put(s:cstr) { self.n += 1 }
}
let main():int32 {
    return 0
}
// error: '.put' of struct Box declared before this call takes (const String^), and these are (cstr): an overload declared after it is not seen here, as C sees none; declare the one meant before the call, as a prototype
