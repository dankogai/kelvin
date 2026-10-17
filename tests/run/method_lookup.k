// a method or an attribute of the program is found on its own type (#179):
// a struct's count, has and find do not catch the built-in count of a
// cstr or an array, the has of a Dictionary, or the isNull of a pointer
struct tally { items: Array<int64> }
extend tally {
    let count:int64 { .items.count as int64 * 100 }
    let has(v:int64):bool { for x in .items { if x == v { return true } }; return false }
    let find(v:int64):int64 { -42 }
    let isNull:bool { .items.count == 0 }
}
let main():int32 {
    var t:tally = {.items = $[1, 2, 3]}
    let text:cstr := "four"
    var fixed:[int64](2) = [5, 6]
    var d = ${"k": 1}
    var s = $"héllo"
    var p:int64^ := nullptr
    println(t.count, " ", t.has(2), " ", t.find(2), " ", t.isNull)
    println(text.count, " ", fixed.count, " ", d.has("k"), " ", s.count, " ", s.find("l"), " ", p.isNull)
    return 0
}
// out: 300 true -42 false
// out: 4 2 true 5 2 true
