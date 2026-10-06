// struct, union and enum tags are types by their bare name (#29)
#import <stdlib.h> as C
#import <time.h> as C
struct point { x:i32; y:i32; };
struct node { value:i64; next:node^; };      // the struct's own name, inside it
union number { i:i32; f:f32; };
enum color { RED, GREEN, BLUE };
struct timespec;                               // a C struct, declared in Kelvin

let origin():point { return (point){0, 0}; }
let point.moved(dx:i32):point { self.x += dx; return self; }
let name(c:color):cstr { return c == RED ? "red" : "other"; }

let main():i32 {
    var p:point = {1, 2};
    let q:struct point = p.moved(3);          // the long form still works
    let n := malloc(sizeof(node)) as node^;
    n^.value = 7;
    n^.next := nullptr;
    let u:number = {.i = 65};
    let c:color = GREEN;
    var t:timespec = {1, 0};
    let pts:[struct point](2) = [{1, 1}, {2, 2}];
    println(q.cstr, " ", n^.value, " ", u.cstr, " ", name(c), " ", name(RED), " ", t.tv_sec);
    println(sizeof(point), " ", sizeof(struct node), " ", sizeof(color), " ", pts[1].cstr);

    // a variable may share a tag's name; in an expression the name is it
    var point:point = origin();
    println(point.cstr, " ", sizeof(point) == sizeof(struct point));
    free(n);
    return 0;
}
// out: {x: 4, y: 2} 7 <union number> other red 1
// out: 8 16 4 {x: 2, y: 2}
// out: {x: 0, y: 0} true
