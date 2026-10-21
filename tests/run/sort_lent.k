// xs.sort { ... } of owners (#242): an anonymous comparator is lent the
// elements, lets the Array keeps, so nothing is copied for a comparison; a
// named one owns its parameters, so it is given copies, and so is a
// struct's own <, which freed what it was given before; the sort is stable
// out: ["al", "di", "bob", "christine"]
// out: ["di", "christine", "bob", "al"] ["christine", "bob", "al", "di"] ["al", "bob", "christine", "di"]
// out: tom rex
struct pet {
    name: String
    age: int64
}
let <(a:pet, b:pet):bool { return a.age < b.age }
let longer(a:String, b:String):bool { return a.count > b.count }

let main():int32 {
    var names:$[String] = $[]
    names += $"bob"
    names += $"al"
    names += $"christine"
    names += $"di"
    names.sort { a, b in a.count < b.count }
    println(names)
    var r = names.sorted { (a:String, b:String):bool in a > b }
    println(r, " ", names.sorted(longer), " ", names.sorted { $0 < $1 })
    var ps:$[pet] = $[]
    ps += (pet){$"rex", 3}
    ps += (pet){$"tom", 1}
    ps.sort()
    println(ps[0].name, " ", ps[1].name)
    return 0
}
