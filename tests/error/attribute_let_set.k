// a let attribute is computed and never set (#131, #132)
struct rect { w: float64; h: float64 }
let rect.area:float64 { .w * .h }
let main():int32 {
    var r:rect = {2.0, 3.0}
    r.area = 1.0
    return 0
}
// error: 'area' is a let attribute, computed and never set: a var attribute has a setter
