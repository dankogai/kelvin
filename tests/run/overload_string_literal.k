// A text literal fits a String parameter among overloads too (#223): it
// is a String of the text, as for a function of one name, and a method
// overloaded so takes it the same way
// out: String 1 i64 String 6
// out: text 4 number
let h(v:String):cstr { "String" }
let h(v:int64):cstr { "i64" }
let size(s:String):int64 { s.count as int64 }
let size(n:int64):int64 { n }

struct box { n: int64 }
let box.put(s:String):cstr { "text" }
let box.put(n:int64):cstr { "number" }
let box.put(s:String, k:int64):int64 { s.count as int64 + k }

let main():int32 {
    println(h("x"), " ", size("y"), " ", h(1), " ", h($"z"), " ", size("kelvin"))
    let b:box = {0}
    println(b.put("abc"), " ", b.put("ab", 2), " ", b.put(3))
    return 0
}
