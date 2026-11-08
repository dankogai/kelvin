// res.json() (#484), JS's: the body as JSON, a Result<JSON, Error>, or an
// Error where it is not UTF-8, or not JSON, with JSON.parse's message;
// JSON comes from libkJSON, which <fetch> imports, as a program may too
#import <fetch>
#import <JSON>
let main(argc:int32, argv:u8^^):int32 {
    let base:cstr := argv[1]
    var r = fetch(`${base}/json`)
    if let res = r {
        var j = res.json()
        if let v = j {
            println(v.object["name"].string, " ", v.object["tags"].array[1].number, " ", v.object["ok"].boolean)
            println(JSON.stringify(&v))
        }
    }
    var b = fetch(`${base}/badjson`)
    if let res = b {
        println(res.json())
    }
    var n = fetch(`${base}/bytes`)
    if let res = n {
        println(res.json())
    }
    var p = fetch(`${base}/method`, (RequestInit){.method = $"POST", .body = Bytes(`{"n": 1}`)})
    if let res = p {
        println(res.json().is(err))
    }
    var mine = JSON.parse(`[true]`)
    println(JSON.stringify(&mine))
    return 0
}
// out: kelvin 11.0 true
// out: {"name":"kelvin","tags":["c",11],"ok":true,"none":null}
// out: err({message: "fetch: the body is not JSON: an array: unexpected end of text at 5"})
// out: err({message: "fetch: the body is not UTF-8 at byte 0"})
// out: true
// out: [true]
