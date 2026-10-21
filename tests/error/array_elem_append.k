// error: an element of Array<String> is a String, and this is a number
let main():int32 {
    var ws = $[$"a"]
    ws.append(3)
    return 0
}
