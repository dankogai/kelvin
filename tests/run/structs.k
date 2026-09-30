extern fn printf(fmt: *u8, ...) -> i32;

struct Vec2 { x: f64, y: f64 }

struct Body {
    name: *u8,
    pos: Vec2,
    history: [3]Vec2,
    next: *Body,
}

fn add(a: Vec2, b: Vec2) -> Vec2 {
    return Vec2 { x: a.x + b.x, y: a.y + b.y };
}

fn nudge(b: *Body) {
    b.pos.x += 1.0;
    (*b).pos.y = 9.0;
}

fn main() {
    var b = Body { name: "earth", pos: Vec2 { x: 1.0, y: 2.0 } };
    var moon = Body { name: "moon", next: &b };
    nudge(&b);
    printf("%s %.1f %.1f\n", b.name, b.pos.x, b.pos.y);
    b.history[1] = add(b.pos, Vec2 { x: 0.5, y: 0.5 });
    printf("%.1f %.1f %.1f\n", b.history[0].x, b.history[1].x, b.history[1].y);
    printf("%s -> %s\n", moon.name, moon.next.name);
    if b.next == null && moon.next != null {
        printf("links ok\n");
    }
    let empty = Vec2 {};
    printf("%.1f\n", empty.x);
    printf("%d\n", sizeof(Vec2) as i32);
}
// out: earth 2.0 9.0
// out: 0.0 2.5 9.5
// out: moon -> earth
// out: links ok
// out: 0.0
// out: 16
