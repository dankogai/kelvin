// nowhere fits a pointer's parameter alone (#769): given to overloads
// of numbers it fits none, which was C's error of kc's C
let twice(x:int64):int64 { x * 2 }
let twice(x:float64):float64 { x * 2.0 }
let main():int32 {
    println(twice(nowhere))
    return 0
}
// error: twice(...) fits none of its 2 overloads
