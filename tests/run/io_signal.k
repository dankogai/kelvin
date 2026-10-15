// f.signal (#89): the signal that ended a process, once closed; 0 when
// it exited on its own; -1 before, or for an IO that is no process;
// then .status is -1 for a process a signal ended
#import <stdio.h> as C
#import <IO>
let main():i32 {
    var k = IO.popen("kill -9 $$", "r")
    if k.error == 0 {
        println(k.signal, " ", k.status)
        k.close()
        println(k.signal, " ", k.status)
    }
    var t = IO.popen("kill -15 $$", "r")
    if t.error == 0 {
        t.close()
        println(t.signal, " ", t.status)
    }
    var e = IO.popen("exit 3", "r")
    if e.error == 0 {
        e.close()
        println(e.signal, " ", e.status)
    }
    var out = IO.stdout
    println(out.signal, " ", out.status)
    return 0
}
// out: -1 -1
// out: 9 -1
// out: 15 -1
// out: 0 3
// out: -1 -1
// c: kv_io_signal((kv_io *)&k)
