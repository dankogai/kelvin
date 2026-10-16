// .cstr (#22): every type's text as cstr (u8^), on the caller's stack
#import "include/cstr_types.h" as C

struct point { x:int32; y:int32; };
struct segment { from:struct point; to:struct point; tag:cstr; };
struct poly { name:uint8^; corners:[struct point](3); grid:[[uint8](2)](2); scale:float64; };
union number { i:int32; f:float32; };
struct buf { n:int32; a:[int32]; };            // flexible array member
struct mixed { t:ticks_t; who:name_t; o:struct opaque; z:float64 _Complex; on:bool; next:struct mixed^; };
struct named { si:int8^; text:cstr; };
struct labeled { label:label_t; full:full_t; n:int32; };
struct image { w:int32; h:int32; px:[uint8](1048576); };   // its text would be megabytes
struct cnames { name:xmlChar^; u:uint8_t^; h:handle_t; r:rstr_t; z:dc_t; b:bytes_t; };
struct seg { a:struct point; b:struct point; };
struct msg { len:uint32; text:flex_t; };    // never printed, so it needs no .cstr
let seg.cstr_size():int32 { return 2; }         // no clash with kelvinc's size constant
var pts:[struct point](2) = [{1, 2}, {3, 4}];
let first():struct point^ { return &pts[0]; }
let segment():struct seg { return (struct seg){{1, 2}, {3, 4}}; }

let get():struct point { return (struct point){5, 6}; }
let point.moved():struct point { return (struct point){.x + 1, .y}; }

let main():int32 {
    // numbers: plain decimal; floats lossless; bool; a string is itself
    var pi = 3.141592653589793;
    println(pi.cstr, " ", 0.1.cstr, " ", (0.1:float32).cstr, " ", 1.0.cstr);
    println(42.cstr, " ", (-7:int8).cstr, " ", (255:uint8).cstr, " ", (~(0:u128)).cstr);
    println(true.cstr, " ", "text".cstr, " ", nullptr.cstr);

    // structs: derived text, nested, with arrays; unions by name
    var p:struct point = {3, 4};
    var s:struct segment = {p, {7, 8}, "edge"};
    println(p.cstr, " ", s.cstr);
    var poly:struct poly = {"tri", [{0, 0}, {1, 0}, {0, 1}], [[1, 2], [3, 4]], 1.5};
    println(poly.cstr);
    var u:union number = {.i = 1};
    println(u.cstr, " ", get().cstr);
    var b:struct buf = {3};
    println(b.cstr);

    // members of types kelvinc cannot see; long strings are cut
    var m:struct mixed = {7, "c", make_opaque(), 1.0, true, nullptr};
    println(m.cstr);
    var n:struct named = {"hi" as int8^, "0123456789012345678901234567890123456789012345678901234567890123456789"};
    println(n.cstr);
    var l:struct labeled = {"hello, world", {'a', 'b', 'c', 'd'}, 9};
    println(l.cstr, " ", l.label.cstr);

    // results of Kelvin functions and methods are seen; a scalar's buffer
    // stays small however large some struct is
    println(get().moved().cstr, " ", (get().x * 2).cstr, " ", (-1:int32).cstr.size);
    println(segment().a.cstr, " ", first()^.cstr, " ", (get)().cstr, " ", segment().cstr_size());

    // members whose types are spelled in C
    var cn:struct cnames = {"title" as xmlChar^, "u8" as uint8_t^, nullptr, "hello" as rstr_t, 1.0, {1, 2, 3, 4}};
    println(cn.cstr, " ", sizeof(struct msg));

    // a C struct's field named cstr wins, also as a designator
    var c:struct cs = {.cstr = "field", .size = 1};
    println(c.cstr);

    // a pointer to volatile bytes is an address
    var v:uint8 volatile^ := "text";
    println(v.cstr[0] == '0');

    // cstr is u8^
    var name:cstr := "kelvin";
    var q:cstr const := name;
    var names:[uint8^](2) = ["a", "b"];
    println(name.cstr, " ", q, " ", names[1].cstr, " ", name.size == (8 as size_t));

    // the text lives until the enclosing block ends
    var t:cstr;
    for (var k:int32 = 0; k < 1; k += 1)
        t := p.cstr;
    println(t);
    return 0;
}
// out: 3.1415926535897931 0.10000000000000001 0.100000001 1
// out: 42 -7 255 340282366920938463463374607431768211455
// out: true text 0x0
// out: {x: 3, y: 4} {from: {x: 3, y: 4}, to: {x: 7, y: 8}, tag: "edge"}
// out: {name: "tri", corners: [{x: 0, y: 0}, {x: 1, y: 0}, {x: 0, y: 1}], grid: [[1, 2], [3, 4]], scale: 1.5}
// out: <union number> {x: 5, y: 6}
// out: {n: 3, a: [...]}
// out: {t: 7, who: c, o: {...}, z: 1+0i, on: true, next: 0x0}
// out: {si: "hi", text: "0123456789012345678901234567890123456789012345678901234..."}
// out: {label: hello, world, full: abcd, n: 9} hello, world
// out: {x: 6, y: 6} 10 8
// out: {x: 1, y: 2} {x: 1, y: 2} {x: 5, y: 6} 2
// out: {name: title, u: u8, h: 0x0, r: hello, z: 1+0i, b: {...}} 4
// out: field
// out: true
// out: kelvin kelvin b true
// out: {x: 3, y: 4}
