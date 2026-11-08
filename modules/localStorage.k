// modules/localStorage.k - localStorage (#491), JS's Web Storage for a
// program: text by text keys, kept in a file of its own between runs, as a
// browser keeps one an origin's. #import <localStorage> brings in the global
// localStorage, a Storage, read from its file at first use and written back
// at each change, by a file renamed over it. The file is JSON, an object of
// Strings: KELVIN_LOCALSTORAGE where the environment names one, else
// $XDG_DATA_HOME/kelvin/localStorage/<program>.json, else
// ~/.local/share/kelvin/localStorage/<program>.json, <program> the name the
// program was run by. Built by kelvinc --lib into localStorage.kh and the
// library #import <localStorage> links.
//
//     #import <localStorage>
//     var n = i64(localStorage.getItem("runs") ?? $"0") + 1
//     localStorage.setItem("runs", $`${n}`)
//     println("run ", n, " of ", localStorage.path)
#import <JSON>
#import <OS>
#import <IO>

// JS's Storage: its items in the order set, and its file; the type of
// localStorage, the one there is
struct Storage {
    items: Dictionary<String, String>
    file: String
}


extend Storage {
    // the file a program's localStorage is kept in, as said above
    static let defaultPath():String {
        if let given = OS.env("KELVIN_LOCALSTORAGE") {
            if given.count > 0 { return String(given) }
        }
        var args = SYS.argv
        var name = OS.basename(args[0])
        if name.count == 0 { name = $"kelvin" }
        var dir = $""
        if let data = OS.env("XDG_DATA_HOME") {
            if data.count > 0 { dir = String(data) }
        }
        if dir.count == 0 {
            var home = $"."
            if let h = OS.env("HOME") { home = String(h) }
            dir = OS.join(home.cstr, ".local/share")
        }
        var kept = OS.join(dir.cstr, "kelvin/localStorage")
        return OS.join(kept.cstr, $`${name}.json`.cstr)
    }

    // a Storage read from its file, what is not an object of Strings left out
    static let opened(file:String):Storage {
        var items = Dictionary<String, String>()
        if OS.isfile(file.cstr) {
            var f = IO(file.cstr)
            var text = f.string ?? $""
            var j = JSON.parse(&text)
            if j.is(object) {
                for k, v in j.object {
                    if v.is(string) { items[k] = v.string.copy() }
                }
            }
        }
        var st:Storage = {.items = items.copy(), .file = file.copy()}
        return st
    }

    // written back whole, by a file beside it renamed over it
    var save() {
        var o = Dictionary<String, JSON>()
        for k, v in self.items { o[k] = JSON.string(v.copy()) }
        var j = JSON.object(o)
        var text = JSON.stringify(&j, "  ")
        var dir = OS.dirname(self.file.cstr)
        if dir.count > 0 { OS.makedirs(dir.cstr) }
        var tmp = $`${self.file}.${OS.pid}.tmp`
        var f = IO(tmp.cstr, "w")
        if f.error != 0 { return }
        f.print(text, "\n")
        f.close()
        OS.rename(tmp.cstr, self.file.cstr)
    }

    // the value of key, or none
    let getItem(key:cstr):String? {
        return self.items[key]
    }
    var setItem(key:cstr, value:cstr) {
        self.items[key] = String(value)
        self.save()
    }
    var removeItem(key:cstr) {
        if self.items.remove(key) { self.save() }
    }
    var clear() {
        self.items.clear()
        self.save()
    }
    // how many items
    let length:i64 {
        return self.items.count
    }
    // the key of item i, in the order set, or none past the last
    let key(i:i64):String? {
        var keys = self.items.keys
        if i < 0 || i >= keys.count { return none }
        return keys[i].copy()
    }
    // the file it is kept in
    let path:String {
        return self.file.copy()
    }

    // the same of a String's text, by reference, after the cstr's, which
    // they call
    let getItem(key:const String^):String? { self.getItem(key^.cstr) }
    var setItem(key:const String^, value:cstr) { self.setItem(key^.cstr, value) }
    var setItem(key:cstr, value:const String^) { self.setItem(key, value^.cstr) }
    var setItem(key:const String^, value:const String^) { self.setItem(key^.cstr, value^.cstr) }
    var removeItem(key:const String^) { self.removeItem(key^.cstr) }
}

// the program's own, read from its file at its first use, once, as a global
// C cannot initialize is (#493)
var localStorage:Storage = Storage.opened(Storage.defaultPath())
