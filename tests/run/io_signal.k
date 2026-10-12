// f.signal (#89): the signal that ended a process, once closed; 0 when
// it exited on its own; -1 before, or for an IO that is no process;
// then .status is -1 for a process a signal ended
#import <stdio.h> as C
let main():i32 {
    var k = IO.popen("kill -9 $$", "r")
    if k.is(ok) {
        println(k.ok.signal, " ", k.ok.status)
        k.ok.close()
        println(k.ok.signal, " ", k.ok.status)
    }
    var t = IO.popen("kill -15 $$", "r")
    if t.is(ok) {
        t.ok.close()
        println(t.ok.signal, " ", t.ok.status)
    }
    var e = IO.popen("exit 3", "r")
    if e.is(ok) {
        e.ok.close()
        println(e.ok.signal, " ", e.ok.status)
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
// c: kv_io_signal((kv_io *)&(*_kv__kv_res_IO_i32_at_ok(&k)))
