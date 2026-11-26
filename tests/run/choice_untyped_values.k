// a choice between two values of one type kelvinc sees gives a
// declaration its type (#34, #777): variables, Strings, bools, a
// function's results and a nested choice
let twice(x:int64):int64 { x * 2 }
let main():int32 {
    var x:int64 = 3
    var y:int64 = 5
    var q = x > y ? x : y
    var s = q > 4 ? $"big" : $"small"
    var b = q > 4 ? x == 3 : y == 3
    var r = b ? twice(x) : (q > 100 ? x : y)
    q += 1
    s += "!"
    println(q, " ", s, " ", b, " ", r)
    return 0
}
// out: 6 big! true 6
