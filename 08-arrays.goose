import std;

// =====================================================================
// 08 - Arrays (syntax.md section 8, docs/reference.md section 5)
//
// Goose has no single "array" type. It has a FAMILY of array types that
// differ only in what can happen to their size. All of them are stored
// inline as [metadata][elements...]: never a pointer to a separate block.
//
//   T[k]       fixed:      exactly k elements, k is a compile-time constant
//   T[]        variable:   sized at construction, then frozen (u32 length)
//   T[u8] T[u16] T[u32] T[u64]   same, with a length of that width
//   T[varint]  variable:   same, with a LEB128 length (1 byte when short)
//   T[..k]     limited:    capacity k inline, grows/shrinks within it
//   T[..]      limited:    capacity chosen at construction
//   T[>..]     grow-only:  the workhorse growable array
//   T[>..<]    grow-shrink: stacks, queues, heaps (the one that pops)
// =====================================================================

// A helper that takes a FIXED array of exactly 4 bytes.
// A literal of constants adapts to a parameter of the shape it fits.
fn take(c: u8[4]) -> i64 { c[3] }            // returns the last byte, widened to i64

// Named constants can be used as compile-time sizes.
const N = 3;                                  // a named constant (compile-time)

fn main() {
    // ---------------------------------------------------------------
    // Fixed arrays: T[k]
    // The size k must be a compile-time constant (literal, named constant,
    // or arithmetic on them). There are NO size generics: fn f<N>(a: i64[N])
    // is an error because a type parameter is a type, never a size.
    // ---------------------------------------------------------------
    var fixed: i32[4] = [1, 2, 3, 4];         // four i32s, stored inline, no length field
    fixed[0] = 10;                            // indexing with [i]; `var` lets us write
    print("fixed: ", fixed, " len=", fixed.len);   // .len is an i64 on every array kind

    let consts: i64[N * 2] = [0; N * 2];      // size from constant arithmetic (6)
    print("const-sized: ", consts);

    // ---------------------------------------------------------------
    // Fill form: [value; count]
    // count must be a compile-time constant; value is evaluated ONCE.
    // ---------------------------------------------------------------
    let zeros: f64[8] = [0.0; 8];             // eight 0.0s
    print("zeros: ", zeros, " len=", zeros.len);

    // ---------------------------------------------------------------
    // Frozen arrays: T[] and friends
    // Sized once at construction and never resized after that.
    // ---------------------------------------------------------------
    let frozen: i64[] = [7, 8, 9];            // a u32 length followed by 3 i64s
    let short_len: i32[u8] = [1, 2];          // same idea, but the length is a u8 (max 255)
    let packed: u8[varint] = "hi";            // a 1-byte varint length + the bytes 'h','i'
    print("frozen: ", frozen, " u8-len: ", short_len, " varint: ", packed);
    // Note: a u8[] array prints as its bytes (text), others print as [a, b, c].

    // ---------------------------------------------------------------
    // Limited arrays: T[..k] and T[..]
    // They grow and shrink, but only within a capacity.
    // Exceeding the capacity aborts at run time.
    // ---------------------------------------------------------------
    var small: u8[..8] = [];                  // capacity 8 stored INLINE (fixed-size type!)
    small.push('h');                          // push a byte (a char literal is an integer)
    small.push('i');
    print("small: ", small, " len=", small.len, " cap=", small.cap);   // .cap on limited arrays

    var sized: i64[..] = [..16];              // [..cap] literal: capacity 16 chosen NOW, length 0
    sized.push(1);                            // grows within the 16-element capacity
    print("sized: ", sized, " len=", sized.len, " cap=", sized.cap);

    // ---------------------------------------------------------------
    // Grow-only: T[>..]  (the default growable array)
    // "Grow-only" names the guarantee: references into it STAY VALID
    // FOREVER, because growth never moves memory.
    // ---------------------------------------------------------------
    var grow: i64[>..] = [];                  // empty; element type from the annotation
    for i in 5 { grow.push(i * i); }          // `for i in 5` loops i = 0..4
    print("grow: ", grow);

    // ---------------------------------------------------------------
    // Grow-shrink: T[>..<]  (stacks, queues, heaps)
    // References into a T[>..<] may live only in LOCAL variables (never in
    // storage), so the compiler can check them at every shrink.
    // ---------------------------------------------------------------
    var stack: i64[>..<] = [];
    stack.push(1); stack.push(2); stack.push(3);
    let top = stack.pop();                    // removes and returns the last element
    print("stack: ", stack, " popped=", top);

    // ---------------------------------------------------------------
    // `var out = [];` with no type: a T[>..] whose element type T is
    // decided by the FIRST push/append/format/assignment, which must
    // come before any other use of `out`.
    // ---------------------------------------------------------------
    var out = [];                             // element type not yet known
    out.push(2.5);                            // now `out` is an f64[>..]
    out.push(1.0);
    print("out (f64[>..]): ", out);

    // A literal with NO destination type is a fixed T[k]: [1, 2, 3] is i64[3].
    print("[1, 2, 3].len = ", [1, 2, 3].len);
    // A literal of constants adapts to the parameter's shape (here u8[4]).
    print("take([0,0,0,7]) = ", take([0, 0, 0, 7]));
    // Arrays of small strings: a fixed array of limited u8 arrays.
    let names: u8[..8][3] = ["a", "bb", "ccc"];
    print("names: ", names);                  // nested u8 arrays print quoted

    // ---------------------------------------------------------------
    // Members (UFCS: a.push(v) is exactly the same call as push(a, v))
    //   .len .cap .push .append .pop .pop_n .resize .clear .index_of
    // ---------------------------------------------------------------
    var xs: i64[>..<] = [];
    xs.push(1);                               // builds in place; returns a reference T&
    push(xs, 100);                            // UFCS: the same as xs.push(100)
    xs.pop();                                 // drop the 100 again
    xs.append([2, 3, 4]);                     // append an array, slice or literal
    let last .= xs.push(5);                   // `.=` binds the returned REFERENCE (T&)
    print("index_of(last) = ", xs.index_of(last));   // 4: index of the element `last` refers to
    print("len=", xs.len, " pop=", xs.pop());        // .len is i64; pop returns the last element
    xs.resize(6, 0);                          // grow to 6 with copies of 0 (or shrink)
    print("after resize(6, 0): ", xs);
    xs.pop_n(2);                              // drop the last 2 elements
    print("after pop_n(2): ", xs);
    xs.resize(2);                             // resize(n) with no value: shrink only here
    print("after resize(2): ", xs);
    xs.clear();                               // empty the array
    print("after clear: len=", xs.len);

    // ---------------------------------------------------------------
    // References into T[>..] stay valid forever (growth never moves memory).
    // pop/clear/resize on a T[>..] are allowed ONLY where nothing still
    // points into it (checked by liveness, not scope).
    // ---------------------------------------------------------------
    var arena: i64[>..] = [];
    let first .= arena.push(42);              // a reference to element 0
    for i in 100 { arena.push(i); }           // lots of growth...
    print("ref into grow-only still valid: ", first);   // ...first is still 42
    arena.clear();                            // OK: `first` is no longer used below
    // print(first);                          // if this line were enabled, the clear()
                                              // above would be a compile error: a reference
                                              // into `arena` would still be live.
    print("arena after clear: len=", arena.len);

    // ---------------------------------------------------------------
    // Element rules
    // * Elements of T[>..<], T[..k] and T[..] must be FIXED-size.
    // * An array of variable-size elements (e.g. u8[][>..], an array of
    //   strings) is SEQUENTIAL: iterate it, but you cannot index it.
    // ---------------------------------------------------------------
    var words: u8[][>..] = [];                // each element is a variable-size u8[]
    for i in 3 { words.push(str("w", i)); }   // str builds the text directly in the new slot
    for w in words { print("word: ", w); }    // iterating is fine
    // print(words[0]);                       // ERROR: arrays of variable-size elements
                                              // cannot be indexed, only iterated
    // var bad: u8[][>..<] = [];              // ERROR: grow-shrink elements must be fixed-size

    // ---------------------------------------------------------------
    // Equality: == compares arrays STRUCTURALLY (length, then elements).
    // Different array kinds compare too, as slices, when element types match.
    // ---------------------------------------------------------------
    let g2: i64[>..] = [0, 1, 4, 9, 16];
    print("grow == g2: ", grow == g2);        // true: same length and elements
    // Gotcha: a bare literal [10, 2, 3, 4] is an i64[4], and == needs operands of
    // the same type, so `fixed == [10, 2, 3, 4]` (i32[4] vs i64[4]) is a compile
    // error. Give the literal a typed home first:
    let want: i32[4] = [10, 2, 3, 4];
    print("fixed == want: ", fixed == want);
    print("small == \"hi\": ", small == "hi");  // u8[..8] vs string literal: true

    // ---------------------------------------------------------------
    // copy(x): an EXPLICIT copy. A non-fixed value is NEVER copied implicitly.
    // ---------------------------------------------------------------
    var b = copy(fixed);                      // explicit O(n) copy of the fixed array
    b[0] = 99;                                // changing the copy...
    print("fixed: ", fixed, " copy: ", b);    // ...leaves the original alone

    let c = grow;                             // NO copy: c names the SAME array as grow
    grow.push(25);                            // grow changes...
    print("c sees grow's push: ", c);         // ...and c sees it (same array)
    var d = copy(grow);                       // an independent grow-only array
    d.push(36);
    print("grow: ", grow, " d: ", d);
}
