// separate compilation (#281): main.k and util.k, each compiled by
// kelvinc -c, then linked by kelvinc, objects alone or with this source;
// util.k's functions are declared here by their prototypes
let digits(s:String^):bool
let ids():Set<int64>
let label(n:int64):String
let main():int32 {
    var s = ${1}
    var t = ids()
    s += &t
    var w = $"a12"
    println(digits(&w), " ", s, " ", label(42))
    return 0
}
// out: true {1, 7, 8} n=42
