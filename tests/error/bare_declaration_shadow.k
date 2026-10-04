// error: declarations start with let or var: write 'var count:...'
var count:i32 = 5
tally(n:i32):i32 {
    count:i32
    count = n * 2
    return count
}
main():i32 {
    println(tally(3))
    return 0
}
