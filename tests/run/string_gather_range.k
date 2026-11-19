// an index past a String's graphemes ends the program, as s[i] does (#617)
let main():int32 {
    let s = $"h👍🏽"
    println("before ", s.gather($[1, 0]))
    println(s.gather($[0, 2]))
    return 0
}
// out: before 👍🏽h
// exit: 1
// err: kelvin: index 2 is out of range: the String has 2 graphemes
