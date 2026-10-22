// only a String has '+' (#282): two cstrs do not join
let main():int32 {
    let x:cstr := "a"
    let y:cstr := "b"
    println(x + y)
    return 0
}
// error: '+' joins Strings, and a cstr is not one (#282): make one a String, as in '$"a" + "b"'
