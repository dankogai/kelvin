// OS's users, groups and a file's owner, written in Kelvin in
// runtime/os.k (#305); a name differs from system to system, group 0
// "wheel" or "root", and a test may run as root, so they are compared
let named(n:String?, want:cstr):bool {
    if let some(s) = n { return s == String(want) }
    return false
}
#import <IO>
#import <errno.h> as C
let main():int32 {
    let me = OS.user
    println(me != none, " ", named(OS.username(0), "root"), " ", OS.username(987654) == none, " ", OS.groupname(0) != none, " ", OS.groupname(987654) == none)
    if let some(m) = me { println(named(OS.username(OS.uid), m.cstr)) }
    let gs = OS.groups.ok
    println(gs.count > 0)
    var f = IO("os_g4.file", "w")
    f.close()
    println(OS.symlink("os_g4.file", "os_g4.link"), " ", OS.chown("os_g4.file", OS.uid, OS.gid), " ", OS.lchown("os_g4.link", OS.uid, OS.gid), " ", OS.chown("os_g4.none", OS.uid, OS.gid) == ENOENT, " ", OS.lchown("os_g4.none", 0, 0) == ENOENT)
    println(OS.uid == 0 || OS.chown("os_g4.file", 0, 0) == EPERM)
    println(OS.remove("os_g4.link"), OS.remove("os_g4.file"))
    return 0
}
// out: true true true true true
// out: true
// out: true
// out: 0 0 0 true true
// out: true
// out: 00
