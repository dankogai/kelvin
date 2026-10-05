// error: '.hex' text lives in a buffer of this function, which is gone once it returns
where(p:i32^):cstr { p.hex }
main():i32 {
    var x:i32 = 1
    println(where(&x))
    return 0
}
