// A brainfuck compiler: the program from the file named on the command
// line, or the echo program built in, as Kelvin source on stdout, which
// kelvinc then compiles. The tape is 65536 cells that wrap, as the pointer
// does. A `!` ends the program and starts its input, as swift-bf has it:
// the input is then baked into the program, and `,` reads it, giving 0 at
// its end; without one, `,` reads stdin, giving 0 at its end. Unmatched
// brackets are reported with their offset.

//     kelvinc -o bfc examples/bfc.k && ./bfc hello.b > hello.k && kelvinc -o hello hello.k
#import <stdio.h> as C

// the input as a Kelvin string literal: C's escapes, octal for the rest
let literal(input:Bytes^):() {
    putchar('"')
    for c in input^ {
        if c == '"' || c == '\\' {
            putchar('\\')
            putchar(c)
        } else if c == '\n' {
            fputs("\\n", stdout)
        } else if c == '\t' {
            fputs("\\t", stdout)
        } else if c >= ' ' && c < 127 {
            putchar(c)
        } else {
            printf("\\%03o", c)
        }
    }
    putchar('"')
}

let indent(depth:int64):() {
    for _ in 0..<depth { fputs("    ", stdout) }
}

// compiles src to Kelvin on stdout; 1 and a message on stderr for brackets
// that do not match
let compile(src:Bytes^):int32 {
    let n = src^.count as int64
    var end = n                          // where the program ends: the first !
    var i:int64 = 0
    while i < n {
        if src^[i] == '!' {
            end = i
            break
        }
        i += 1
    }
    let embedded = end < n
    var input = Bytes()
    if embedded { input = src^[end + 1...] }
    println("#import <stdio.h> as C")
    if !embedded {
        println("let read():u8 {")
        println("    let c:i32 = getchar()")
        println("    return c < 0 ? 0 : c as u8")
        println("}")
    }
    println("let main():i32 {")
    println("    var tape = Bytes(65536)")
    println("    var sp:i64 = 0")
    if embedded {
        print("    var input = Bytes(")
        literal(&input)
        println(")")
        println("    var at:i64 = 0")
    }
    var depth:int64 = 1
    var opens:$[int64] = $[]               // the offsets of the [ still open
    i = 0
    while i < end {
        let c = src^[i]
        if c == ']' {
            if opens.count == 0 {
                fprintf(stderr, "unmatched ] at offset %s\n", i.cstr)
                return 1
            }
            opens.pop()
            depth -= 1
        }
        if c == '>' || c == '<' || c == '+' || c == '-' || c == '.' || c == ',' || c == '[' || c == ']' {
            indent(depth)
        }
        switch c {
        case '>': println("sp = (sp + 1) % 65536")
        case '<': println("sp = (sp + 65535) % 65536")
        case '+': println("tape[sp] += 1")
        case '-': println("tape[sp] -= 1")
        case '.': println("putchar(tape[sp])")
        case ',':
            if embedded {
                println("if at < input.count as i64 { tape[sp] = input[at] } else { tape[sp] = 0 }")
                indent(depth)
                println("at += 1")
            } else {
                println("tape[sp] = read()")
            }
        case '[':
            println("while tape[sp] != 0 {")
            opens += i
            depth += 1
        case ']': println("}")
        default:
        }
        i += 1
    }
    if opens.count > 0 {
        fprintf(stderr, "unmatched [ at offset %s\n", opens[0].cstr)
        return 1
    }
    println("    return 0")
    println("}")
    return 0
}

let echo := "+[,<>.]-!Hello, Kelvin!\n"   // the eight commands, and their input after the !

let main(argc:int32, argv:[cstr]):int32 {
    if argc > 1 {
        let f:FILE^ := fopen(argv[1], "r")
        if f.isNull {
            perror(argv[1])
            return 1
        }
        var src = Bytes()
        var c:int32 = fgetc(f)
        while c >= 0 {
            src += c as uint8
            c = fgetc(f)
        }
        fclose(f)
        return compile(&src)
    }
    var e = Bytes(echo)
    return compile(&e)
}
// out: #import <stdio.h> as C
// out: let main():i32 {
// out:     var tape = Bytes(65536)
// out:     var sp:i64 = 0
// out:     var input = Bytes("Hello, Kelvin!\n")
// out:     var at:i64 = 0
// out:     tape[sp] += 1
// out:     while tape[sp] != 0 {
// out:         if at < input.count as i64 { tape[sp] = input[at] } else { tape[sp] = 0 }
// out:         at += 1
// out:         sp = (sp + 65535) % 65536
// out:         sp = (sp + 1) % 65536
// out:         putchar(tape[sp])
// out:     }
// out:     tape[sp] -= 1
// out:     return 0
// out: }
