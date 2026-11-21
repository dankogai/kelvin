// what #665 leaves as it was: shifts by less than the width, a literal
// made an i64 by :i64 or by a method on it (#548), a u8 made an int
let i64.plus(k:i64):i64 { self + k }
let main():int32 {
    var x:i64 = 1
    var y:u8 = 1
    println(x << 60 >> 58, " ", 1:i64 << 40, " ", (1 << 40).plus(1), " ", y << 9, " ", 1 << 30)
    return 0
}
// out: 4 1099511627776 1099511627777 512 1073741824
