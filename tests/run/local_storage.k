// localStorage (#491), JS's: #import <localStorage> brings in the global,
// read from its file at first use, KELVIN_LOCALSTORAGE's here, which is
// JSON, an object of Strings, what is not a String left out; setItem,
// removeItem and clear write it back at once, by a file renamed over it;
// getItem and key give a String?, length how many, in the order set
#import <localStorage>
#import <IO>
#import <OS>
let shown(path:cstr) {
    var f = IO(path)
    var text = f.string ?? $""
    var j = JSON.parse(&text)
    println(JSON.stringify(&j))
}
let main():int32 {
    var dir = OS.mkdtemp("kelvin-ls")
    var file = OS.join(dir.ok.cstr, "store.json")
    var given = IO(file.cstr, "w")
    given.print(`{"runs": "41", "n": 7, "name": "kelvin"}`)
    given.close()
    OS.setenv("KELVIN_LOCALSTORAGE", file.cstr)
    println(localStorage.length, " ", localStorage.getItem("runs"), " ", localStorage.getItem("n"), " ", localStorage.path == file)
    var runs:i64 = i64(localStorage.getItem("runs") ?? $"0") + 1
    localStorage.setItem("runs", `${runs}`)
    var k = $"lang"
    var v = $"Kelvin"
    localStorage.setItem(&k, &v)
    println(localStorage.getItem(&k), " ", localStorage.key(0), " ", localStorage.key(2), " ", localStorage.key(3))
    shown(file.cstr)
    localStorage.removeItem("name")
    localStorage.removeItem("none")
    shown(file.cstr)
    localStorage.clear()
    println(localStorage.length)
    shown(file.cstr)
    OS.remove(file.cstr)
    OS.rmdir(dir.ok.cstr)
    return 0
}
// out: 2 some("41") none true
// out: some("Kelvin") some("runs") some("lang") none
// out: {"runs":"42","name":"kelvin","lang":"Kelvin"}
// out: {"runs":"42","lang":"Kelvin"}
// out: 0
// out: {}
