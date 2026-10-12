// f.kill(signal) (#91): a signal to a process IO.exec or IO.popen started
// (#100), true when sent; f.pid its pid, -1 for any other IO; after
// kill, close waits and .signal says which
#import <signal.h> as C
let main():i32 {
    var p = IO.exec(["sleep", "30"], "r")
    if p.is(ok) {
        println(p.ok.pid > 0, " ", p.ok.kill(SIGTERM))
        p.ok.close()
        println(p.ok.signal, " ", p.ok.status, " ", p.ok.pid, " ", p.ok.kill(SIGTERM))
    }
    var k = IO.exec(["sleep", "30"], "r")
    if k.is(ok) {
        println(k.ok.kill(9))
        k.ok.close()
        println(k.ok.signal)
    }
    var sh = IO.popen("sleep 30", "r")
    if sh.is(ok) {
        println(sh.ok.pid > 0, " ", sh.ok.kill(SIGTERM))
        sh.ok.close()
        println(sh.ok.signal, " ", sh.ok.status)
    }
    var out = IO.stdout
    println(out.pid, " ", out.kill(0))
    return 0
}
// out: true true
// out: 15 -1 -1 false
// out: true
// out: 9
// out: true true
// out: 15 -1
// out: -1 false
// c: kv_io_kill((kv_io *)&(*_kv__kv_res_IO_i32_at_ok(&p)), SIGTERM)
// c: kv_io_pid((kv_io *)&out)
