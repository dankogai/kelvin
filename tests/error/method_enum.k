// error: enums cannot have methods: C cannot tell an enum from its integer type
enum color { RED, GREEN };
let color.name():cstr { return "?"; }
