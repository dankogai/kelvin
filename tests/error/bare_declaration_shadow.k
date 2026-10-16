// error: declarations start with let or var: write 'var count:...'
var count:int32 = 5
let tally(n:int32):int32 {
    count:int32
    count = n * 2
    return count
}
let main():int32 {
    println(tally(3))
    return 0
}
