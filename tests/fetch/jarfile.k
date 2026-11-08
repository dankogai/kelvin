// a jar's file (#490): jar.save(path) writes its live cookies as Netscape's
// cookies.txt, curl's, by a file renamed over path, and jar.load(path) adds
// a file's, the same name, domain and path replaced, those ended left out,
// curl's #HttpOnly_ lines read as any; each gives the count, or an Error
#import <fetch>
#import <IO>
#import <OS>
let main(argc:int32, argv:u8^^):int32 {
    let base:cstr := argv[1]
    var dir = OS.mkdtemp("kelvin-jar")
    let d:cstr := dir.ok.cstr
    var jar = CookieJar()
    var s = fetch(`${base}/setcookie`, (RequestInit){.cookies = jar})
    var l = fetch(`${base}/login`, (RequestInit){.cookies = jar})   // session=abc, a session's
    println(s.ok.status, " ", l.ok.status, " ", jar.count)
    var saved = jar.save(`${d}/cookies.txt`)
    println(saved)
    var f = IO(`${d}/cookies.txt`)
    for r in f.lines {
        if let line = r { if line.starts("#") { println(line) } }
        break
    }
    var back = CookieJar()
    println(back.load(`${d}/cookies.txt`), " [", back.getCookieString(`${base}/x`), "]")
    var hand = IO(`${d}/hand.txt`, "w")
    hand.print("# a file by hand\n\n")
    hand.print("#HttpOnly_.example.com\tTRUE\t/\tFALSE\t0\tsid\t42\n")
    hand.print("www.example.com\tFALSE\t/app\tTRUE\t4102444800\ttoken\tt1\n")
    hand.print("example.com\tFALSE\t/\tFALSE\t1\tgone\tx\n")
    hand.print("example.com\tFALSE\t/\tFALSE\t0\tempty\t\n")
    hand.close()
    var other = CookieJar()
    let n = other.load(`${d}/hand.txt`)
    println(n, " [", other.getCookieString("https://www.example.com/app/x"), "] [", other.getCookieString("http://example.com/"), "]")
    var bad = IO(`${d}/bad.txt`, "w")
    bad.print("example.com\tFALSE\t/\n")
    bad.close()
    println(other.load(`${d}/bad.txt`).err.message.ends("/bad.txt, line 1, is not a cookie of cookies.txt: 7 fields by tabs"))
    println(other.load(`${d}/none.txt`).err.message.starts(`fetch: cannot read a jar from ${d}/none.txt: `))
    println(jar.save(`${d}/no/such/dir/cookies.txt`).is(err))
    OS.remove(`${d}/cookies.txt`)
    OS.remove(`${d}/hand.txt`)
    OS.remove(`${d}/bad.txt`)
    OS.rmdir(d)
    return 0
}
// out: 200 200 4
// out: ok(4)
// out: # Netscape HTTP Cookie File
// out: ok(4) [a=1; b=2; c=3; session=abc]
// out: ok(3) [token=t1; sid=42] [sid=42; empty=]
// out: true
// out: true
// out: true
