// runtime/iter.k - Iterator<T> (#325): a state and a function, Swift's
// sequence(state:next:), written in Kelvin (#289): kelvinc --runtime
// builds it into libkelvin, each kv_ function by the name kelvin_prelude.h
// declares. The C kelvinc writes puts the state on the heap and gives its
// function as next, which writes the T? it gives into out; an Iterator is
// an owner, whose end frees the state.
#import <stdlib.h> as C

// Iterator(state) { ... }: the state, on the heap, and what walks it
let kv_iter_make(state:any^, drop:(any^):(), next:(any^, any^):()):kv_iter {
    var it:kv_iter
    it.state := state
    it.drop := drop
    it.next := next
    return it
}

// it.next(): the next value, or none, written into out
let kv_iter_next(it:kv_iter^, out:any^) {
    if it^.state == nullptr { kv_array_fail("this Iterator was moved out") }
    it^.next(it^.state, out)
}

// an Iterator's end: its state freed, and what it owns
let kv_iter_free(it:kv_iter^) {
    if it^.state == nullptr { return }
    if it^.drop != nullptr { it^.drop(it^.state) }
    free(it^.state)
    it^.state := nullptr
}

let kv_iter_take(it:kv_iter^):kv_iter {
    let v:kv_iter = it^
    it^.state := nullptr
    return v
}

let kv_iter_copy(it:const kv_iter^):kv_iter {
    kv_array_fail("an Iterator is not copied: pass it on, or walk it")
    return it^
}

// it = Iterator(...): the old one freed, the new one kept
let kv_iter_assign(it:kv_iter^, v:kv_iter) {
    kv_iter_free(it)
    it^ = v
}

let kv_iter_discard(v:kv_iter) {
    var it:kv_iter = v
    kv_iter_free(&it)
}
