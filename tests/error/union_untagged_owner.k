// a union with no tag cannot hold an owner either (#54, #60)
let main():i32 {
    var u:union{b:Bytes} = {}
    return 0
}
// error: a union cannot hold an owner (#54): which member to free is unknown
