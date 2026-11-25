// an Array, a Dictionary and a Set of structs are named by the structs'
// bare names (#758), Array<point>, as a point? is and as kc names them,
// where kelvinc's .typename and its errors said Array<struct point>
struct point { x:int64, y:int64 }
enum color { red, green }
let count(xs:const $[point]^):int64 { xs^.count as int64 }
let main():int32 {
    var a:$[point] = $[{1, 2}]
    var d:${String: point} = ${:}
    var n:$[$[point]] = $[]
    var o:point? = none
    var c:$[color] = $[red]
    var p:$[point^] = $[]
    var q:${int64: $[point]} = ${:}
    println(a.typename, " ", d.typename, " ", n.typename, " ", o.typename)
    println(c.typename, " ", p.typename, " ", q.typename, " ", (&a).typename, " ", count.typename)
    println(a, " ", count(&a))
    return 0
}
// out: Array<point> Dictionary<String, point> Array<Array<point>> point?
// out: Array<color> Array<point^> Dictionary<i64, Array<point>> Array<point>^ (const Array<point>^):i64
// out: [{x: 1, y: 2}] 1
