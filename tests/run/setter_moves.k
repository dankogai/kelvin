// a variable that owns moves into a setter, as into any function (#474):
// the setter frees what it takes, so the variable holds nothing after it,
// and its block frees nothing; a subscript's index moves in too
struct person { name: String }
extend person {
    var title:String {
        get { .name.copy() }
        set(v) { .name = v.copy() }
    }
}
struct names { xs: Array<String> }
extend names {
    var [](i:int64):String {
        get { .xs[i].copy() }
        set(v) { .xs[i] = v.copy() }
    }
    let [](k:String):int64 { k.count as int64 }
}
let main():int32 {
    var p:person = {$"Ada"}
    let a = $"Grace"
    p.title = a
    var n:names = {$[$"a", $"b"]}
    let b = $"bee"
    n[1] = b
    let k = $"four"
    println(p.title, " ", n[1], " ", n[k], " ", n.xs)
    return 0
}
// out: Grace bee 4 ["a", "bee"]
