import std;

// =====================================================================
// 09 - Strings and printing (syntax.md section 9, docs/reference.md section 6)
//
// There is NO string type. A string is just an array of u8 bytes, and
// WHICH array kind you pick says what you want to do with it:
//
//   u8[>..]              a builder (appending is a pointer bump)
//   u8[], u8[varint]     a finished string, stored inline
//   u8[..16]             a small inline string (great inside a struct)
//   u8[:] / const u8[:]  a view of bytes living elsewhere;
//                        a string LITERAL is a `const u8[:]` (read-only static data)
//
// No encoding is enforced: UTF-8 is only a library convention
// (each_utf8 / push_utf8 understand it).
// =====================================================================

// ---------------------------------------------------------------------
// Custom text form: an overload of the `format` hook.
// Signature: fn format(out: u8[>..]&, v: T). Whenever a T appears in an
// argument of print / str / format, this overload renders it. The overload
// is looked up in T's namespace first, then globally, so the TYPE decides
// how it prints, not the code doing the printing.
// ---------------------------------------------------------------------
struct Person { name: u8[..16], age: i32 }    // u8[..16]: a small inline string field
fn format(out: u8[>..]&, p: Person) { format(out, p.name, " (", p.age, ")"); }

// A struct WITHOUT a format overload, to show the default structural text form.
struct Point { x: i64, y: i64 }

fn main() {
    // ---------------------------------------------------------------
    // The four string roles
    // ---------------------------------------------------------------
    var s: u8[>..] = [];                      // builder: a grow-only byte array
    s.append("hello");                        // append a whole string (array/slice/literal)
    s.push(',');                              // push ONE byte (a char literal is an integer)
    format(s, " world! ", 6 * 7);             // format appends the TEXT of any values
    print("builder: ", s, " [", s.len, " bytes]");

    let owned: u8[] = "fixed";                // a writable COPY of the literal (length + 5 bytes)
    let vint: u8[varint] = "tiny";            // finished string with a 1-byte varint length
    var small: u8[..16] = "abc";              // small inline string, capacity 16
    small.push('!');                          // limited arrays are builders too, up to capacity
    let view: const u8[:] = s[..5];           // a VIEW of the first 5 bytes of s (no copy)
    let lit = "literal";                      // a string literal: type const u8[:]
    print("owned=", owned, " vint=", vint, " small=", small, " view=", view, " lit=", lit);
    // A literal is read-only static data; it may only be stored in a `const` slot.
    // Copying it into any u8 array (like `owned`) gives you a writable value.

    // ---------------------------------------------------------------
    // str(...): build a FRESH u8[>..] holding the text of its arguments
    // ---------------------------------------------------------------
    let t = str("n=", 42, " pi=", 3.14);      // a new builder, constructed in place
    print("str: ", t, " (len ", t.len, ")");

    // ---------------------------------------------------------------
    // print(...): takes ANY number of values of ANY type, adds a newline.
    // print, format and str insert NOTHING between arguments: spaces are yours.
    // ---------------------------------------------------------------
    print("answer=", 42, " ok=", true);       // ints, bools...
    print("no", "spaces", "added");           // -> nospacesadded
    print(1, 2, 3);                           // -> 123  (no separators!)

    // There is NO string interpolation: "x={x}" is just those literal bytes.
    let x = 5;
    print("x={x} stays literal; concatenate instead: x=", x);

    // ---------------------------------------------------------------
    // Text forms of non-string values
    // ---------------------------------------------------------------
    print("struct: ", Point { 1, 2 });        // Point { 1, 2 }: positional literal + type name
    let arr: i64[3] = [1, 2, 3];
    print("array: ", arr);                    // [1, 2, 3]
    let nothing: i64? = null;
    print("null optional: ", nothing);        // null
    print("floats: ", 1.0, " ", 0.1, " ", 2.5e10);  // shortest form that reads back the same
    let nested: u8[..4][2] = ["ab", "cd"];
    print("nested strings are quoted: ", nested);   // ["ab", "cd"]

    // ---------------------------------------------------------------
    // Gotcha: 'a' is an INTEGER, not a character.
    // ---------------------------------------------------------------
    print("str('x') = ", str('x'));           // "120"! the number's text, not the letter
    print("\"text\"[0] = ", "text"[0]);       // 116: indexing a string gives a byte (u8)
    var built: u8[>..] = [];
    built.push('x');                          // the RIGHT way to append the byte 'x'
    print("pushed 'x': ", built);
    var caps: u8[>..] = [];
    for c in "abc" { caps.push(c - 'a' + 'A'); }    // bytes are numbers: arithmetic works
    print("uppercased by arithmetic: ", caps);

    // ---------------------------------------------------------------
    // Custom text form via the format overload (defined above)
    // ---------------------------------------------------------------
    let ann = Person { "ann", 30 };
    print(ann);                               // ann (30)   <- uses our format overload
    var people: Person[>..] = [];
    people.push(Person { name: "ada", age: 36 });
    people.push(Person { name: "grace", age: 45 });
    print("people: ", people, " str len of first: ", str(people[0]).len);
    var p2 = Person { name: "", age: 20 };
    format(p2.name, "linus");                 // format into a limited u8[..16] field
    print("p2: ", p2);

    // ---------------------------------------------------------------
    // String helpers from std (they all work on u8[:] views)
    // ---------------------------------------------------------------
    let line = "  key = some value  ";
    let body = trim(line);                    // trim: slice without leading/trailing whitespace
    let eq = find(body, "=");                 // find: first index of a substring, -1 if none
    print("trim: '", body, "'  find('='): ", eq, "  find('zzz'): ", find(body, "zzz"));
    print("key='", trim(body[..eq]), "' value='", trim(body[eq + 1..]), "'");
    print("rfind('e'): ", rfind(body, "e"));  // rfind: LAST occurrence
    print("starts_with key: ", starts_with(body, "key"),
          "  ends_with value: ", ends_with(body, "value"));

    let parts = split("alice,30,paris", ','); // split: array of SLICES into the input (no copy)
    print("split: ", parts.len, " parts ", parts);
    print("split on a string sep: ", split("a::b::c", "::"));
    print("words: ", words("  go   north "));   // words: whitespace-separated, never empty

    var joined: u8[>..] = [];
    join(joined, parts, " | ");               // join: append parts with a separator to a builder
    print("join: ", joined);

    let n, ok = parse_int("42");              // parse_int returns TWO values: value, success
    let h, hok = parse_int("ff", 16);         // optional base argument
    let bad, bok = parse_int("nope");
    print("parse_int: ", n, " ", ok, "  hex ff: ", h, " ", hok, "  'nope': ", bad, " ", bok);
    let f, fok = parse_flt("-2.5e3");         // parse_flt: value, success
    print("parse_flt: ", f, " ", fok);

    var mixed: u8[>..] = [];
    mixed.append("MiXeD Case");
    to_lower(mixed);                          // to_lower: IN PLACE on a writable slice
    print("to_lower: ", mixed);
    to_upper(mixed);                          // to_upper: in place as well
    print("to_upper: ", mixed);
    // to_upper("abc");                       // ERROR: a literal is const u8[:], not writable

    // each_split / each_word: run a block per part, without building an array.
    // Inside the block, `it` is the current part (a slice).
    var count = 0;
    each_split("a,b,,c", ',') { count += 1; };   // 4 parts (one is empty)
    print("each_split part count: ", count);
    var longest = 0;
    each_word("the quick brown fox") { if it.len > longest { longest = it.len; } };
    print("each_word longest word length: ", longest);

    // each_utf8 / push_utf8: UTF-8 code points.
    let greek = "αβγ";                         // 3 letters, 6 bytes in UTF-8
    var cps = 0;
    each_utf8(greek) { cps++; };              // `it` is each decoded code point (i64)
    var shifted: u8[>..] = [];
    each_utf8(greek) { push_utf8(shifted, it + 1); };   // encode the next letter of each
    print("utf8: ", greek.len, " bytes, ", cps, " code points, shifted: ", shifted);

    // ---------------------------------------------------------------
    // Equality: == compares bytes structurally, across array kinds.
    // ---------------------------------------------------------------
    print("builder == literal: ", t == "n=42 pi=3.14", "  owned == \"fixed\": ", owned == "fixed");
}
