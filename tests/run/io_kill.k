// f.kill(signal) (#91): a signal to a process IO.exec or IO.popen started
// (#100), true when sent; f.pid its pid, -1 for any other IO; after
// kill, close waits and .signal says which
#import <signal.h> as C
#import <IO>
let main():int32 {
    var p = IO.exec(["sleep", "30"], "r")
    if p.error == 0 {
        println(p.pid > 0, " ", p.kill(SIGTERM))
        p.close()
        println(p.signal, " ", p.status, " ", p.pid, " ", p.kill(SIGTERM))
    }
    var k = IO.exec(["sleep", "30"], "r")
    if k.error == 0 {
        println(k.kill(9))
        k.close()
        println(k.signal)
    }
    var sh = IO.popen("sleep 30", "r")
    if sh.error == 0 {
        println(sh.pid > 0, " ", sh.kill(SIGTERM))
        sh.close()
        println(sh.signal, " ", sh.status)
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
// c: kv_io_kill((kv_io *)&p, SIGTERM)
// c: kv_io_pid((kv_io *)&out)
