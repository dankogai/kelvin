// error: f(...) fits more than one of its overloads equally: say which Optional none is, as in 'Optional<i64>()' (#222)
let f(v:int64?):cstr { return "i64?" }
let f(v:String?):cstr { return "String?" }

let main(argc:int32, argv:[cstr]):int32 {
    println(f(none))
    return 0
}
