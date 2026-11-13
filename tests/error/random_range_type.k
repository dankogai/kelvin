// a Range of another type is not T.random's (#547): a range written
// there is of T, and a variable's is its own
let main():int32 {
    let r:Range<u8> = 1...6
    println(i64.random(r))
    return 0
}
// error: i64.random(r) takes a Range<i64>, as in 'i64.random(1...6)', and this is Range<u8>
