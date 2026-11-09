// Word frequencies: RegExp splits the text, a Set<String> leaves out the
// common words, a Dictionary<String, i64> counts the rest in the order
// they come, and an Array of structs that own their words sorts by count.
// RegExp is the prelude's (#504), with no import.

struct tally {
    word:  String
    count: i64
}

let main():i32 {
    let text = $"""The quick brown fox jumps over the lazy dog.
The dog sleeps; the fox runs, and the quick fox is gone."""
    let blanks = $/[^A-Za-z]+/
    let common = ${$"the", $"and", $"is", $"over"}
    var counts:Dictionary<String, i64> = ${:}
    for w in text.lower().split(&blanks) {
        if w.isEmpty || common.has(w) { continue }
        counts[w] = counts.get(w, 0) + 1
    }
    println(counts.count, " words: ", counts)
    var tallies:$[tally] = $[]
    for w, n in counts { tallies += (tally){w.copy(), n} }
    tallies.sort { $0.count > $1.count || $0.count == $1.count && $0.word < $1.word }
    for t in tallies.prefix(3) { println(t.word, " ", t.count) }
    return 0
}
// out: 9 words: {"quick": 2, "brown": 1, "fox": 3, "jumps": 1, "lazy": 1, "dog": 2, "sleeps": 1, "runs": 1, "gone": 1}
// out: fox 3
// out: dog 2
// out: quick 2
