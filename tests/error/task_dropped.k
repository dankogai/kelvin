// a Task is bound and awaited (#312): dropped, it would be awaited at once
let hello() { println("x") }
let main():int32 {
    async hello()
    return 0
}
// error: a Task dropped here would be awaited at once: bind it, 'let t = async f(x)', and await it when its value is wanted
