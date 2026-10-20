// d[k] read whole is an Optional (#218): some of a copy of the value, or
// none where the key is missing; x! unwraps any Optional, or ends the
// program; x?.m, x?.f() and x?[i] chain, none of none; going into d[k],
// =, +=, .m, [i], &d[k] and d[k]!, is the place it was, checked
struct person { name: String; age: int64 }
let older(d:Dictionary<String, int64>^):int64 { return d^["ann"]! + 1 }
let main():int32 {
    var ages:Dictionary<String, int64> = ${:}
    ages["ann"] = 31
    ages["ann"] += 1
    let a = ages["ann"]
    let b = ages["bob"]
    println(a, " ", b, " ", ages["ann"]!, " ", ages["bob"] ?? 0, " ", a!, " ", b.is(none), " ", older(&ages))
    var names:Dictionary<int64, String> = ${:}
    names[1] = $"one"
    println(names[1], " ", names[2], " ", names[1]?.count, " ", names[2]?.count, " ", names[1]!.count)
    var people:Dictionary<String, person> = ${:}
    people["p"] = {$"pat", 40}
    println(people["p"]?.name, " ", people["q"]?.name, " ", people["p"]?.age, " ", people["p"]!.name)
    if let some(p) = people["p"] { println(p.name, " is ", p.age) }
    var lists:Dictionary<String, $[int64]> = ${:}
    lists["x"] = $[1, 2, 3]
    lists["x"].append(4)                               // a place
    println(lists["x"]?[3], " ", lists["y"]?[0], " ", lists["x"]!.count)
    var maybe:String? = $"hello"
    println(maybe?.count, " ", maybe!, " ", maybe?.count ?? 0)
    var opts:${String: int64?} = ${"a": 1, "b": none}
    println(opts["a"] ?? 0, " ", opts["b"] ?? 0, " ", opts["c"] ?? 0, " ", opts["a"]! ?? 0)
    return 0
}
// out: some(32) none 32 0 32 true 33
// out: some("one") none some(3) none 3
// out: some("pat") none some(40) pat
// out: pat is 40
// out: some(4) none 4
// out: some(5) hello 5
// out: some(1) none some(0) 1
// c: _kv_dict_String_i64_find(&(ages), "bob")
