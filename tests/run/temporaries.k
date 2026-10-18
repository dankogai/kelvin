// an owner that an expression gives is held where it is used (#187): in a
// hidden local, freed once the postfix chain, the comparison or the loop
// around it is done; a member that owns is copied out, and an owner given
// where a borrow is taken is lent, as $/\s+/ to a const RegExp^
#import <RegExp>
#import <SION>
#import <UnicodeData>
struct rec { name: String; n: int64 }
struct bag { d: Dictionary<String, int64> }
let bag[](k:cstr):int64 { 7 }
let make():rec { var r:rec = {.name = $"ann", .n = 3}; return r }
let rows():$[int64] { var r = $[1, 2, 3]; return r }
let bags():bag { return {${:}} }
let parse(s:cstr):Result<int64, String> { return int64(s) }
let maybe():int64? { return 1 }
let main():int32 {
    var words = $"Hello, Kelvin!".split($/\s+/)                // a String held, a RegExp lent
    println(words, " ", $"héllo".count, " ", Bytes("xyz").count, " ", rows()[1], " ", bags()["k"])
    var name = make().name                                      // the member, copied out
    var tail = rows()[1..<3]
    println(name, " ", make().n, " ", tail, " ", $"Straße".fold(), " ", parse("1").is(ok))
    println(rows(), " ", $"a" + "b", " ", make(), " ", String("x").copy())
    let t := `${$"tpl"} ${rows()} and ${make()}`
    var u = $`${$"x"} and more`
    println(t, " ", u)
    let n = int64($"12")
    var s = SION.parse("[\"a\": \"text\"]")
    println(s["a"].string, " ", n, " ", maybe() ?? 0, " ", parse("2") ?? -1)
    println(parse("1") == parse("1"), " ", $"a" < $"b", " ", $"x" == $"x")
    var sum:int64 = 0
    for x in rows() { sum += x }
    for w in $"a bb ccc".split($/ /) { sum += w.count as int64 }
    println(sum, " ", $"abc".has(&$"b"), " ", $"x-y".replace($/-/, "+"))
    return 0
}
// out: ["Hello,", "Kelvin!"] 5 3 2 7
// out: ann 3 [2, 3] straße true
// out: [1, 2, 3] ab {name: "ann", n: 3} x
// out: tpl [1, 2, 3] and {name: "ann", n: 3} x and more
// out: text 12 1 2
// out: true true true
// out: 12 true x+y
