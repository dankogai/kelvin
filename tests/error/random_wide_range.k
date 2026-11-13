// an integer of 128 bits has no Range (#373), so its random takes none (#547)
let main():int32 {
    println(i128.random(1...6))
    return 0
}
// error: i128.random() takes no range: a Range is of integers of 64 bits or fewer
