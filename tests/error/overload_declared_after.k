// an overload declared after a call is not seen there, as C sees no
// function before its declaration (#492): where the one seen does not take
// the arguments, an error says so, not a C warning and a call of the wrong one
let f(s:const String^) { f(s^.cstr) }
let f(s:cstr) { println(s) }
let main():int32 {
    return 0
}
// error: 'f' declared before this call takes (const String^), and these are (cstr): an overload declared after it is not seen here, as C sees none; declare the one meant before the call, as a prototype
