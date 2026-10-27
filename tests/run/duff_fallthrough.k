// what Duff's device does, written with fallthrough (#401): the remainder
// by a cascade of cases, then whole blocks in a loop; the device itself, a
// case inside the loop, is left out on purpose, and cc -O2 unrolls a loop
let copy(to:u8^, from:const u8^, count:i64):() {
    var i = 0
    switch count % 4 {
    case 3: to[i] = from[i]; i += 1; fallthrough
    case 2: to[i] = from[i]; i += 1; fallthrough
    case 1: to[i] = from[i]; i += 1
    default: break
    }
    while i < count {
        to[i] = from[i]; to[i + 1] = from[i + 1]
        to[i + 2] = from[i + 2]; to[i + 3] = from[i + 3]
        i += 4
    }
}
let main():i32 {
    var buf = [u8](16)
    let text:cstr := "Duff's device!"
    copy(&buf[0], text, 15)
    println(&buf[0] as cstr)
    var two = [u8](8)
    copy(&two[0], "ab", 2)
    println(two[0], " ", two[1], " ", two[2])
    return 0
}
// out: Duff's device!
// out: 97 98 0
