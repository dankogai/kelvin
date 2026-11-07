// a variable that moved into a setter holds nothing after it (#474)
struct person { name: String }
extend person {
    var title:String {
        get { .name.copy() }
        set(v) { .name = v.copy() }
    }
}
let main():int32 {
    var p:person = {$"Ada"}
    let a = $"Grace"
    p.title = a
    println(a)
    return 0
}
// error: 'a' was moved out and holds nothing now
