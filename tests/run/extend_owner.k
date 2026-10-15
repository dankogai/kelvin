// attributes of a type that owns (#131, #132): a getter gives a copy of a
// String, a setter takes one, which moves in, and the old one is freed
struct person { name: String; age: int64 }
extend person {
    var title:String {
        get {
            var t = $"Dr. "
            t += &.name
            return t
        }
        set(v) { .name = v.copy() }
    }
    let older:Self { (Self){.name.copy(), .age + 1} }
}
let main():i32 {
    var p:person = {$"Ada", 36}
    var t = p.title
    println(t)
    p.title = $"Grace"
    var o = p.older
    println(p.name, " ", o, " ", o.age)
    return 0
}
// out: Dr. Ada
// out: Grace {name: "Grace", age: 37} 37
