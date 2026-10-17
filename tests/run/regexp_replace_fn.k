// RegExp (#158): replace with a function of the Match, a trailing anonymous
// function, which owns the Match it is given; String(n) of a number
#import <RegExp>
let main():int32 {
    let re = $/(-?\d+(?:\.\d+)?)F/g
    var s = $"212F and 32F, then -40F"
    var t = s.replace(&re) { String((f64($0.text[1]) - 32.0) * 5.0 / 9.0) }
    var u = re.replace(&s) { $`[${$0.start}..<${$0.end}]` }
    var v = s.replace(&re, "<$1>")
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
// out: 100 and 0, then -40
// out: [0..<4] and [9..<12], then [19..<23]
// out: <212> and <32>, then <-40>
// out: 10/2026 and 2027-01 true and 2027-01
