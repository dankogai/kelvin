// an Iterator of Strings made lazy (#327): each value its base gives is
// lent to an anonymous function, a copy given to a named one, and freed
// unless filter keeps it; the base, moved in, is freed with it
let shout(s:String):String { s + "!" }
let words(n:int64):Iterator<String> {
    return Iterator($[0, n]) {
        if $0[0] >= $0[1] { return none }
        $0[0] += 1
        var s = $"w"
        s += String($0[0])
        return s
    }
}
let main():int32 {
    var loud = words(3).lazy.map(shout)
    let first = loud.next()
    println(first, " ", loud.filter { $0 != $"w3!" })
    for s in words(4).lazy.filter({ $0 != $"w2" }).lazy.map({ $0 + $0 }) { print(s, ",") }
    println()
    var unwalked = words(9).lazy.map { $0 + $"?" }
    let one = unwalked.next()
    println(one)
    return 0
}
// out: some("w1!") ["w2!"]
// out: w1w1,w3w3,w4w4,
// out: some("w1?")
