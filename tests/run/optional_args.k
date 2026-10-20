// An argument where a function or a method takes an Optional or a Result
// (#222) is what a return's value would be: none, some(T) of a T, ok(v)
// and err(e). An owner moves in. Among overloads, one that takes the
// arguments as they are wins: g(5) is g(i64), and g(none) g(i64?)
// out: -1 4 5 6
// out: 42 7
// out: 101 3 7 3
// out: -1
// out: i64? String? i64? String?
// out: i64 i64? i64?
struct box {
    n: int64
}

extend box {
    let plus(v:int64?):int64 { return .n + (v ?? 100) }
    static let of(v:int64?):box { return {v ?? 7} }
}

let later(v:String?):int64 { return v?.count ?? 0 - 1 }

let verdict(r:Result<int64, String>):int64 {
    if let err(why) = r { return why.count as int64 }
    return r.ok
}

let f(v:int64?):cstr { return "i64?" }
let f(v:String?):cstr { return "String?" }
let g(v:int64):cstr { return "i64" }
let g(v:int64?):cstr { return "i64?" }

let main(argc:int32, argv:[cstr]):int32 {
    var owned = $"moved!"
    println(later(none), " ", later("four"), " ", later($"three"), " ", later(owned))
    println(verdict(ok(42)), " ", verdict(err($"seven..")))
    let b:box = {1}
    println(b.plus(none), " ", b.plus(2), " ", box.of(none).n, " ", box.of(3).n)
    println(later(argc > 5 ? "x" : none))
    let x:int64? = 1
    println(f(x), " ", f(Optional<String>()), " ", f(5), " ", f($"x"))
    println(g(5), " ", g(x), " ", g(none))
    return 0
}
