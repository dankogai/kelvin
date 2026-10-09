// an Array of owners (#57): Strings, Bytes and Arrays as elements, freed
// with it; xs[i] = v frees the old element; copy() copies them; append of
// a borrow copies them; each element in turn is borrowed, not moved
let main():i32 {
    var names = Array<String>()
    names += String("ada")
    names += String("linus")
    names[0] = String("grace")
    names.insert(1, String("ken"))
    for n in names { print(n, " ", n.count, " ") }
    println()
    var copy = names.copy()
    copy.remove(0, 1)
    copy += &names
    let last = copy.pop()
    println(copy.count, " ", names.count, " ", last, " ", copy[0], " ", names[2])
    var bs = Array<Bytes>(2)
    bs[1] += "xyz"
    bs.clear()
    bs += Bytes("q")
    var rows = Array<Array<i64>>()
    rows += Array<i64>(3)
    rows[0][1] = 5
    rows += rows[0].copy()
    rows[1] += 9
    println(rows[1].count, " ", rows[1][1], " ", bs.count, " ", bs[0])
    return 0
}
// out: grace 5 ken 3 linus 5 
// out: 4 3 linus ken linus
// out: 4 5 1 q
// c: KV_ARRAY(kv_string, _kv_array_String, kv_string_free, kv_string_copy)
// c: kv_string_assign(_kv_array_String_at(&names, 0), KV_STRING_OF("grace"));
