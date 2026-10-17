// RegExp (#158): replace with a function of the Match, a trailing anonymous
// function, which owns the Match it is given; String(n) of a number
#import <RegExp>
let main():int32 {
    let re = $/\d+(\.\d+)?/g
    var s = $"1.5 and 2, then 10"
    var t = s.replace(&re) { String(f64($0.text[0]) * 2.0) }
    var u = re.replace(&s) { $`[${$0.start}..<${$0.end}]` }
    var v = s.replace(&re, "<$&>")
    println(t)
    println(u)
    println(v)
    let dated = $/(?<y>\d{4})-(?<m>\d\d)/
    var d = $"2026-10 and 2027-01"
    var w = d.replace(&dated) { (m:Match):String in
        var y = m["y"]
        var mo = m["m"]
        return $`${mo}/${y}`
    }
    var x = d.replace(&dated) { String($0.has(1)) }
    println(w, " ", x)
    return 0
}
// out: 3 and 4, then 20
// out: [0..<3] and [8..<9], then [16..<18]
// out: <1.5> and <2>, then <10>
// out: 10/2026 and 2027-01 true and 2027-01
