// a program with a type of its own named RegExp brings in no prelude
// RegExp (#504): its names are its own, as before
struct RegExp { pattern: cstr; hits: i64 }
struct Match { at: i64 }
let main():int32 {
    let r:RegExp = {"a+", 2}
    let m:Match = {5}
    println(r.pattern, " ", r.hits, " ", m.at)
    return 0
}
// out: a+ 2 5
