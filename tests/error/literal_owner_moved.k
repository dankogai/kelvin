// a local owner that moved into a struct's literal holds nothing (#503)
struct P { name: String; n: int64 }
let main():int32 {
    var s = $"a"
    let p = (P){s, 1}
    println(p, " ", s)
    return 0
}
// error: 's' was moved out and holds nothing now: assign it anew before using it
