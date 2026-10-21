// map, filter and reduce lend an owner element to an anonymous function
// (#244), a let the Array or Dictionary keeps, read and never moved, so
// nothing is copied for it; a named function, and a parameter written
// var, get a copy of their own; reduce's value so far moves in and out
// out: [3, 2, 9] ["bob!", "al!", "christine!"] ["bob", "al", "christine"] ["bob?", "al?", "christine?"] ["bob", "christine"] bobalchristine
// out: ["al", "bob", "christine"]
// out: {1: 3, 2: 5} {2: "three"} onethree 11
let loud(s:String):String { return s + "!" }

let main():int32 {
    var names = $[$"bob", $"al", $"christine"]
    var counts = names.map { s in s.count as int64 }
    var shouts = names.map(loud)
    var copies = names.map { s in s.copy() }
    var tagged = names.map { (var s:String):String in
        s += "?"
        return s
    }
    var lengthy = names.filter { s in s.count > 2 }
    let joined = names.reduce($"") { acc, s in acc + s }
    println(counts, " ", shouts, " ", copies, " ", tagged, " ", lengthy, " ", joined)
    names.sort { (var a:String, b:String):bool in
        a += "z"
        return a < b
    }
    println(names)
    var d = ${1: $"one", 2: $"three"}
    var sizes = d.map { v in v.count as int64 }
    var big = d.filter { v in v.count > 3 }
    let all = d.reduce($"") { acc, v in acc + v }
    let keyed = d.reduceWithKey(0) { acc, k, v in acc + k + v.count as int64 }
    println(sizes, " ", big, " ", all, " ", keyed)
    return 0
}
