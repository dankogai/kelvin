// where libkfetch was built with HAS_SSL=0, an https URL is an Error that
// says so (#482); http works as ever
// needs: nossl
#import <fetch>
let main(argc:int32, argv:u8^^):int32 {
    var r = fetch(`${argv[2]}/hello`)
    println(r.err.message)
    var h = fetch(`${argv[1]}/hello`)
    println(h.ok.status)
    return 0
}
// out: fetch: HTTPS is not built in: libkfetch was built with HAS_SSL=0
// out: 200
