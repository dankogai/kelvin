// a member, or a case, of an array of arrays of owners (#371): each
// innermost element freed and copied with it, whatever the counts
struct pair { grid: [[String](2)](2) }
enum slot { empty; grid: [[String](2)](2) }
let main():int32 {
    var p:pair = {[[$"w", $"x"], [$"y", $"z"]]}
    p.grid[1][0] = $"Y"
    let q = p.copy()
    var s = slot.grid([[$"a", $"b"], [$"c", $"d"]])
    let t = s.copy()
    s.grid = [[$"e", $"f"], [$"g", $"h"]]
    println(p, " ", q.grid[1][0])
    println(s, " ", t)
    return 0
}
// out: {grid: [["w", "x"], ["Y", "z"]]} Y
// out: grid([["e", "f"], ["g", "h"]]) grid([["a", "b"], ["c", "d"]])
// c: kv_string_free(&((kv_string *)self->grid)[_kv_i]);
