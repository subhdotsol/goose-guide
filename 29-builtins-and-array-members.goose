import std;

// =====================================================================
// 29. Builtins and array members
//
// Builtins are the language's OWN functions (everything else lives in the
// standard library, written in Goose). They need no import.
//
// | Builtin                                   | Meaning                                  |
// |-------------------------------------------|------------------------------------------|
// | print(a, b, ...)                          | print the values and a newline           |
// | str(a, b, ...)                            | a fresh u8[>..] holding their text       |
// | format(out, a, b, ...)                    | append their text to `out`               |
// | assert(c), abort(msg), exit(code)         | checks and stopping                      |
// | copy(x)                                   | an explicit copy                         |
// | default<T>()                              | the default value of T                   |
// | to_bytes, bytes_of, from_bytes<T>         | serialization                            |
// | embed_file(path), embed_shader(...)       | compile-time file or shader embedding    |
// | thread_spawn, thread_spawn_contained,     | threads                                  |
// |   thread_wait, hardware_threads           |                                          |
// | qput, qget<T>, qpoll<T>, qlimit<T>        | queues                                   |
//
// Array members: .len .cap .push .append .pop .pop_n .resize .clear .index_of
// Pool members:  .alloc_index .alloc_ref .free .alloc_slice .realloc_slice .free_slice
// =====================================================================

// A struct with field defaults, used by default<T>() below.
struct Rec { id: i64 = 7, tag: u8[..4] = "none", score: f64 = 1.5 }

// A flat, fixed-size struct for the pool / serialization demos.
struct Item { id: i32, weight: f32 }

// embed_file: the bytes of a file, read when the program is COMPILED, as a
// read-only view of static data (const u8[:]). The path is relative to the
// file containing the call and must be a literal (or a let/const global).
// Here we embed THIS very source file, so no extra file is needed.
let SELF_SOURCE: const u8[:] = embed_file("29-builtins-and-array-members.goose");

fn main() {
    // -----------------------------------------------------------------
    // print(a, b, ...): renders every argument as text, then a newline,
    // all in ONE write. Any number of arguments, of any printable type.
    // -----------------------------------------------------------------
    print("print: ", 42, " ", 2.5, " ", true, " ", [1, 2, 3]);
    print();                                   // no arguments: just a newline

    // -----------------------------------------------------------------
    // str(a, b, ...): same rendering as print, but returns a FRESH string
    // (u8[>..], a growable byte array) instead of writing it out.
    // -----------------------------------------------------------------
    let s = str("x=", 10, ", y=", 20);         // "x=10, y=20"
    print("str: ", s, " (len ", s.len, ")");   // a u8[>..] has .len like any array

    // -----------------------------------------------------------------
    // format(out, a, b, ...): APPENDS the text to an existing growable u8
    // array. Useful for building output piece by piece without new strings.
    // -----------------------------------------------------------------
    var buf: u8[>..] = [];                     // empty growable byte array
    format(buf, "a=", 1);                      // buf = "a=1"
    format(buf, ", b=", 2.0);                  // appended: "a=1, b=2.0"
    print("format: ", buf);

    // -----------------------------------------------------------------
    // assert(c): aborts the program unless c holds. c is a bool, or an
    // optional - in which case assert also NARROWS it to non-null.
    // abort(msg): ends the program with a message. exit(code): ends the
    // program with an exit code. Neither returns, and none is catchable.
    // -----------------------------------------------------------------
    assert(1 + 1 == 2);                        // holds: nothing happens
    var ys: i64[>..] = [5, 6];
    let maybe: i64&? = ys.push(9);             // an optional reference (push returns T&)
    assert(maybe);                             // narrows: `maybe` is now known non-null
    print("assert: passed, narrowed value = ", maybe);
    // assert(1 > 2);                          // would abort with the failing source location
    // abort("something went wrong");          // would abort and print the message
    // exit(3) is used at the very end of main, with code 0.

    // -----------------------------------------------------------------
    // copy(x): an explicit, visible copy. Fixed-size values copy silently;
    // NON-fixed values (growable arrays, ...) are never copied implicitly.
    // -----------------------------------------------------------------
    var a: i64[>..] = [1, 2, 3];
    var b = copy(a);                           // a fresh O(n) copy
    b.push(4);                                 // changes only b
    let c = a;                                 // NO copy: c names the same array as a
    c.push(5);                                 // so this changes a too
    print("copy: a=", a, " b=", b);            // a=[1, 2, 3, 5] b=[1, 2, 3, 4]
    // var d: i64[>..] = a;                    // error: value destination needs copy(a)

    // -----------------------------------------------------------------
    // default<T>(): the value a fixed-size T has before anything is written:
    // zeros, with the struct's declared field defaults applied.
    // -----------------------------------------------------------------
    print("default<i64>() = ", default<i64>(), ", default<bool>() = ", default<bool>());
    print("default<Rec>() = ", default<Rec>());   // uses the field defaults
    print("default<Item>() = ", default<Item>()); // no defaults declared: all zero

    // -----------------------------------------------------------------
    // Serialization:
    //   to_bytes(a)      -> u8[>..]: a framed image (varint byte count + elements)
    //   to_bytes(a, out) appends that image to `out` instead
    //   bytes_of(a)      -> u8[:]: the element region alone, a read-only view, no copy
    //   from_bytes<T[>..]>(b) -> T[>..], bool: a VERIFIED array from untrusted
    //                     bytes; false and an empty array if the image is invalid
    // -----------------------------------------------------------------
    var items: Item[>..] = [];
    items.push(Item { id: 1, weight: 0.5 });
    items.push(Item { id: 2, weight: 1.5 });
    let image = to_bytes(items);               // fresh framed image
    var out: u8[>..] = [];
    to_bytes(items, out);                      // the same image appended to `out`
    print("to_bytes: ", image.len, " bytes, appended form: ", out.len, " bytes");
    print("bytes_of: ", bytes_of(items).len, " bytes (2 items x 8 bytes)");
    let loaded, ok = from_bytes<Item[>..]>(image);   // two results: value and success flag
    print("from_bytes: ok=", ok, " loaded=", loaded);
    let junk: u8[3] = [99, 1, 2];              // claims 99 bytes but only has 2
    let bad, bok = from_bytes<Item[>..]>(junk);
    print("from_bytes(junk): ok=", bok, " len=", bad.len);

    // -----------------------------------------------------------------
    // embed_file(path): see SELF_SOURCE above (the bytes are baked in).
    // embed_shader(...): compiles GLSL at compile time into a shader blob
    // for the graphics module, e.g.
    //     let vs = embed_shader("vert", """ ...glsl source... """);
    //     let fs = embed_shader("lit.frag");
    // Not shown running: it needs the graphics module and a GLSL compiler.
    // -----------------------------------------------------------------
    print("embed_file: this file is ", SELF_SOURCE.len, " bytes, starts with \"",
          SELF_SOURCE[0..11], "\"");           // "import std;"

    // -----------------------------------------------------------------
    // Threads and queues. NOT runnable with `goose file.goose`: the
    // in-process JIT aborts with "JIT mode does not support threads yet".
    // Build with `goose build` to run this (verified separately):
    //
    //   struct Job { n: i32 }
    //   thread_fn worker(k: i32) {             // worker entry point
    //       let j = qget<Job>();               // qget<T>(): take next T, blocking
    //       qput(Job { n: j.n * 2 + k });      // qput(v): enqueue on T's queue -> bool
    //   }
    //   thread_fn fails() { abort("boom"); }
    //   // in main:
    //   print(hardware_threads() > 0);         // a sensible worker count
    //   qlimit<Job>(4);                        // queue for Job holds at most 4
    //   qput(Job { n: 20 });
    //   let id = thread_spawn(worker, 2);      // start a worker -> id (i64)
    //   thread_wait(id);                       // block until it ends -> bool
    //   let r, got = qpoll<Job>();             // non-blocking: value + flag (42 true)
    //   var why: u8[>..] = [];
    //   let cid = thread_spawn_contained(fails); // its abort ends only that worker
    //   print(thread_wait(cid, why), " ", why); // false, plus the abort message
    // -----------------------------------------------------------------

    // =================================================================
    // Array members
    // =================================================================

    // .len: element count, on every array kind and on slices
    let fixed: i64[4] = [10, 20, 30, 40];
    print(".len of fixed array: ", fixed.len, ", of slice fixed[1..3]: ", fixed[1..3].len);

    // .cap: the capacity, only on limited arrays T[..k] / T[..]
    var lim: i64[..4] = [];                    // inline capacity 4
    lim.push(1);
    print(".cap: len=", lim.len, " cap=", lim.cap);
    // lim.push(2); lim.push(3); lim.push(4); lim.push(5);  // 5th push aborts: over capacity

    // .push(v): adds one element (built in place), returns a REFERENCE to it
    var xs: i64[>..<] = [];                    // grow-shrink: supports every member below
    xs.push(1);                                // result ignored
    let last .= xs.push(5);                    // `.=` binds the returned reference
    print(".push: xs=", xs, ", returned ref reads ", last);

    // .append(src): copies in the elements of an array, slice or array literal
    xs.append([2, 3, 4]);
    xs.append(fixed[0..2]);                    // a slice works too
    print(".append: xs=", xs);

    // .index_of(r): the index of the element reference r points at
    // (r must be provably a reference INTO this very array)
    print(".index_of(last) = ", xs.index_of(last));    // 1

    // .pop(): removes and returns the last element
    let popped = xs.pop();
    print(".pop: got ", popped, ", xs=", xs);

    // .pop_n(n): drops the last n elements
    xs.pop_n(2);
    print(".pop_n(2): xs=", xs);

    // .resize(n, v) grows with copies of v; .resize(n) shrinks
    xs.resize(7, 0);
    print(".resize(7, 0): xs=", xs);
    xs.resize(3);
    print(".resize(3): xs=", xs);

    // .clear(): empties the array
    xs.clear();
    print(".clear: len=", xs.len);
    // xs.pop();                               // shrinking below empty aborts at run time

    // Shrinks (pop, pop_n, resize-down, clear) are for grow-shrink T[>..<]
    // and limited arrays; a grow-only T[>..] only allows them where the
    // compiler can prove no reference into the dropped part survives.

    // =================================================================
    // Pool members: a `reusable` grow-only array of fixed-size elements
    // is paired with a hidden freelist. Every slot stays a live value.
    // =================================================================
    reusable var pool: Item[>..] = [];
    let s0 = pool.alloc_index(Item { id: 10, weight: 1.0 });  // index of a slot holding v
    let s1 = pool.alloc_index(Item { id: 11, weight: 1.0 });
    pool.free(s0);                             // slot 0 recorded for reuse (no memory freed)
    let s2 = pool.alloc_index(Item { id: 12, weight: 2.0 });  // reuses slot 0
    let node .= pool.alloc_ref(Item { id: 13, weight: 3.0 }); // same, but returns a reference
    print("alloc_ref -> ", node);
    pool.free(pool.index_of(node));            // reference -> slot index -> freed
    print("pool: slots ", s0, " ", s1, " ", s2, ", len ", pool.len, ", ", pool);

    // `reusable[]`: a SLICE pool hands out runs of elements instead of slots
    reusable[] var spool: i64[>..] = [];
    let ra = spool.alloc_slice(3);             // 3 default (zero) elements
    ra[0] = 1; ra[1] = 2; ra[2] = 3;
    let rb = spool.alloc_slice(2);
    rb[0] = 7; rb[1] = 8;
    spool.free_slice(ra);                      // run recorded for reuse
    let rc = spool.alloc_slice(2);             // taken from the freed run, reset to defaults
    let rd = spool.realloc_slice(rb, 4);       // rb is at the end: grows in place
    print("slice pool: c=", rc, " d=", rd, " len=", spool.len, " ", spool);
    // A slice pool has no alloc_index/alloc_ref/free; a plain pool has no *_slice ops.

    // -----------------------------------------------------------------
    // exit(code): ends the program right here with the given exit code.
    // -----------------------------------------------------------------
    print("exit: calling exit(0)");
    exit(0);
    // print("never printed");                 // unreachable: exit never returns
}
