import std;

// =====================================================================
// 26. Serialization
// ---------------------------------------------------------------------
// Goose links inside an array are SELF-RELATIVE offsets (`Node&<u32>`), so a
// structure means the same thing wherever its bytes sit in memory. Saving is
// therefore just writing its bytes, and loading is reading them back:
//
//   to_bytes(a) -> u8[>..]        a framed image: varint byte count + element region
//   to_bytes(a, out)              the same, APPENDED to an existing buffer
//   bytes_of(a) -> u8[:]          the raw element region, read-only, NO copy
//   from_bytes<T[>..]>(b) -> T[>..], bool
//                                 a VERIFIED array from untrusted bytes;
//                                 a bad image gives false and an empty array
//
// Run: ../oss/goose/build/goose 26-serialization.goose   (from goose-guide)
// =====================================================================

// A binary search tree stored in ONE growable array. left/right are optional
// self-relative references (u32 offsets) to other elements of the same array.
struct Node { word: u8[..8], count: i32, left: Node&<u32>?, right: Node&<u32>? }

// A plain flat struct: serializes just as well (no links to verify).
struct Sample { t: i64, v: f64 }

// Insert a word into the tree held in `pool` (or bump its count).
fn insert(pool: Node[>..]&, word: u8[:]) {
    if pool.len == 0 { pool.push(Node { word: word, count: 1 }); return; }
    var cur .= pool[0];                               // `.=` rebinds a reference
    loop {
        let c = compare(word, cur.word[..]);
        if c == 0 { cur.count += 1; return; }
        let next = if c < 0 { cur.left } else { cur.right };
        if next { cur .= next; continue; }
        if c < 0 { cur.left .= pool.push(Node { word: word, count: 1 }); }
        else { cur.right .= pool.push(Node { word: word, count: 1 }); }
        return;
    }
}

// Count of `word` in the tree, 0 if absent.
fn lookup(pool: Node[>..]&, word: u8[:]) -> i32 {
    guard pool.len > 0 else { return 0; }
    var cur .= pool[0];
    loop {
        let c = compare(word, cur.word[..]);
        if c == 0 { return cur.count; }
        let next = if c < 0 { cur.left } else { cur.right };
        guard next else { return 0; }
        cur .= next;
    }
}

fn main() {
    // Build a small word-count tree.
    var tree: Node[>..] = [];
    each_word("the quick fox and the lazy dog and the fox") { insert(tree, it); };
    print("tree: ", tree.len, " nodes, 'the' x", lookup(tree, "the"));

    // -----------------------------------------------------------------
    // to_bytes(a): a fresh framed image (method-call/UFCS form)
    // -----------------------------------------------------------------
    var image: u8[>..] = tree.to_bytes();
    print("to_bytes image: ", image.len, " bytes");

    // -----------------------------------------------------------------
    // to_bytes(a, out): APPEND an image to an existing buffer
    // -----------------------------------------------------------------
    var buf: u8[>..] = [];
    buf.append("HDR!");                               // e.g. your own file header
    to_bytes(tree, buf);                              // image goes after the header
    print("header + image: ", buf.len, " bytes (4 + ", image.len, ")");

    // -----------------------------------------------------------------
    // bytes_of(a): the element bytes themselves, no framing, no copy
    // -----------------------------------------------------------------
    let view = bytes_of(tree);                        // read-only u8[:] view into `tree`
    print("bytes_of(tree): ", view.len, " bytes");
    // view[0] = 1;   // error: a bytes_of view is never writable — bytes written
    //                // through it would be links the checker never proved.

    // -----------------------------------------------------------------
    // from_bytes<T[>..]>(b): verified load -> (array, ok)
    // -----------------------------------------------------------------
    var loaded, ok = from_bytes<Node[>..]>(image);
    print("from_bytes ok = ", ok, ", ", loaded.len, " nodes, 'the' x", lookup(loaded, "the"),
          ", 'fox' x", lookup(loaded, "fox"));
    // The result is an ordinary array: index it, grow it, reference into it.
    insert(loaded, "cat");
    print("loaded array grows normally: ", loaded.len, " nodes");

    // Loading from the appended buffer: skip our 4-byte header with a slice.
    var again, ok2 = from_bytes<Node[>..]>(buf[4..]);
    print("from_bytes(buf[4..]) ok = ", ok2, ", ", again.len, " nodes");

    // -----------------------------------------------------------------
    // Verification: a corrupt/hostile image gives false + an empty array
    // -----------------------------------------------------------------
    // from_bytes checks the framing, every tag and length, canonical varints,
    // and that every link lands on an element start inside the image — so you
    // never get a wild reference. (It checks SAFETY, not integrity: changed
    // data bytes still load fine; add a checksum yourself if you need one.)
    image[image.len - 3] = 200;                       // tamper with a link
    var bad, bok = from_bytes<Node[>..]>(image);
    print("tampered image: ok = ", bok, ", len = ", bad.len);

    var junk: u8[>..] = [];
    junk.append("not an image at all");
    var bad2, bok2 = from_bytes<Node[>..]>(junk);
    print("junk bytes: ok = ", bok2, ", len = ", bad2.len);

    // -----------------------------------------------------------------
    // Flat structs round-trip too
    // -----------------------------------------------------------------
    var samples: Sample[>..] = [];
    samples.push(Sample { t: 1, v: 0.5 });
    samples.push(Sample { t: 2, v: 1.25 });
    let simg = samples.to_bytes();
    var sback, sok = from_bytes<Sample[>..]>(simg);
    print("samples round trip ok = ", sok, ": ", sback);

    // Limits (from the reference): from_bytes also builds T[>..<] and the
    // T[] family; links into a FIELD of an element and `in pool` links are
    // NOT serializable.
}
