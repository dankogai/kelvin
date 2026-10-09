// a struct that owns is copied with .copy() and may be an Array's
// element (#61), copied and freed with it
struct bag { name: String; items: Array<i64> }
let main():i32 {
    var b:bag = {String("b"), Array([1, 2, 3])}
    var c = b.copy()
    c.name += "2"
    c.items += 4
    println(b.name, " ", b.items.count, " ", c.name, " ", c.items.count)
    var bags = Array<bag>()
    bags += b.copy()
    bags += c.copy()
    bags[0].items += 9
    println(bags.count, " ", bags[0].items.count, " ", bags[1].name, " ", c.items.count)
    var more = Array(&bags)
    more[1].name = String("m")
    println(more.count, " ", more[1].name, " ", bags[1].name)
    return 0
}
// out: b 3 b2 4
// out: 2 4 b2 4
// out: 2 m b2
// c: static inline struct bag _kv_bag_copy(const struct bag *self)
// c: _kv_v.name = kv_string_copy(&self->name);
// c: _kv_v.items = _kv_array_i64_copy(&self->items);
// c: KV_ARRAY(struct bag, _kv_array_bag, _kv_bag_free, _kv_bag_copy)
