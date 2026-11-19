// A brainfuck compiler: the program from the file named on the command
// line, or the echo program built in, as Kelvin source on stdout, which
// kelvinc then compiles. The tape is 65536 cells that wrap, as the pointer
// does. A `!` ends the program and starts its input, as swift-bf has it:
// the input is then baked into the program, and `,` reads it, giving 0 at
// its end; without one, `,` reads stdin, giving 0 at its end. Unmatched
// brackets are reported with their offset. The compiler and what it
// writes read and write by IO, with no header of C's.

//     kelvinc -o bfc examples/bfc.k && ./bfc hello.b > hello.k && kelvinc -o hello hello.k
#import <IO>

// the input as a Kelvin string literal: C's escapes, octal for the rest
let literal(input:Bytes^):String {
    var s = $"\""
    for c in input^ {
        if c == '"' || c == '\\' {
            s += '\\'
            s += c                       // a number appended is its codepoint
        } else if c == '\n' {
            s += "\\n"
        } else if c == '\t' {
            s += "\\t"
        } else if c >= ' ' && c < 127 {
            s += c
        } else {
            s += '\\'
            s += '0' + c / 64
            s += '0' + c / 8 % 8
            s += '0' + c % 8
        }
    }
    s += '"'
    return s
}

let indent(depth:i64):() {
    for _ in 0..<depth { print("    ") }
}

// compiles src to Kelvin on stdout; 1 and a message on stderr for brackets
// that do not match
let compile(src:Bytes^):i32 {
    let n = src^.count as i64
    var end = n                          // where the program ends: the first !
    var i:i64 = 0
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
    println("#import <IO>")
    println("let main():i32 {")
    println("    var tape = Bytes(65536)")
    println("    var sp:i64 = 0")
    println("    var cell = Bytes(1)")
    if embedded {
        println("    var input = Bytes(", literal(&input), ")")
        println("    var at:i64 = 0")
    }
    var depth:i64 = 1
    var opens:$[i64] = $[]               // the offsets of the [ still open
    i = 0
    while i < end {
        let c = src^[i]
        if c == ']' {
            if opens.count == 0 {
                IO.stderr.println("unmatched ] at offset ", i)
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
        case '.':
            println("cell[0] = tape[sp]")
            indent(depth)
            println("IO.stdout.write(&cell)")
        case ',':
            if embedded {
                println("if at < input.count as i64 { tape[sp] = input[at] } else { tape[sp] = 0 }")
                indent(depth)
                println("at += 1")
            } else {
                println("tape[sp] = IO.stdin.byte ?? 0")
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
        IO.stderr.println("unmatched [ at offset ", opens[0])
        return 1
    }
    println("    return 0")
    println("}")
    return 0
}

let echo := "+[,<>.]-!Hello, Kelvin!\n"   // the eight commands, and their input after the !

let main(argc:i32, argv:[cstr]):i32 {
    if argc > 1 {
        let f = IO(argv[1], "r")
        if f.error != 0 {              // the errno when it did not open
            IO.stderr.println(argv[1], ": ", IO.strerror(f.error))
            return 1
        }
        var src = f.bytes              // the whole file
        return compile(&src)
    }
    var e = Bytes(echo)
    return compile(&e)
}
// out: #import <IO>
// out: let main():i32 {
// out:     var tape = Bytes(65536)
// out:     var sp:i64 = 0
// out:     var cell = Bytes(1)
// out:     var input = Bytes("Hello, Kelvin!\n")
// out:     var at:i64 = 0
// out:     tape[sp] += 1
// out:     while tape[sp] != 0 {
// out:         if at < input.count as i64 { tape[sp] = input[at] } else { tape[sp] = 0 }
// out:         at += 1
// out:         sp = (sp + 65535) % 65536
// out:         sp = (sp + 1) % 65536
// out:         cell[0] = tape[sp]
// out:         IO.stdout.write(&cell)
// out:     }
// out:     tape[sp] -= 1
// out:     return 0
// out: }
