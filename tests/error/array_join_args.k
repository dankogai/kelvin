// xs.join(sep) takes the text between the elements alone (#461)
let main():int32 {
    let xs = $[1, 2]
    println(xs.join(", ", "!"))
    return 0
}
// error: '.join' takes the text between the elements, or none: '.join(", ")'
