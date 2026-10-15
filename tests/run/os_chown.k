// OS.chown(path, uid, gid) and OS.lchown (#99): a file's owner, 0 or
// errno; OS.username(uid) and OS.groupname(gid): the names of the ids
// stat gives, String?, none for an id no one has
#import <errno.h> as C
#import <OS>
let main():i32 {
    let path := "os_chown.tmp"
    println(OS.touch(path))
    var s = OS.stat(path)
    println(s.ok.uid == OS.uid)                 // the group may be the directory's, as on macOS
    println(OS.chown(path, OS.uid, OS.gid), " ", OS.lchown(path, OS.uid, -1))   // -1 leaves the group
    var after = OS.stat(path)
    println(after.ok.gid == OS.gid)
    println(OS.chown(path, 0, 0) == EPERM, " ", OS.chown("os_chown.none", OS.uid, OS.gid) == ENOENT)
    var me = OS.username(OS.uid)
    var mine = OS.groupname(OS.gid)
    var root = OS.username(0)
    var nobody = OS.username(999999999)
    println(me.is(some), " ", mine.is(some), " ", root.cstr, " ", nobody.cstr, " ", me.typename)
    var user = OS.user
    println(user.is(some) && me.is(some))
    println(OS.remove(path))
    return 0
}
// out: 0
// out: true
// out: 0 0
// out: true
// out: true true
// out: true true some("root") none String?
// out: true
// out: 0
// c: kv_os_chown(path, kv_os_uid(), kv_os_gid())
// c: kv_os_username(0, &_kv_s) ? _kv__kv_opt_String_make_some(_kv_s) : _kv__kv_opt_String_make_none()
