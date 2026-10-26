import std;

// =====================================================================
// 14. Relative references
//
// A plain `T&` is an 8-byte address that means nothing outside the process.
// A RELATIVE reference stores the same link as a narrow OFFSET instead.
// Loading one gives an ordinary T&; storing one re-encodes the offset.
// They are position-independent and serializable.
//
//   Form                               Meaning
//   T&<u8 | u16 | u32 | u64 | varint>  self-relative: offset from the FIELD to a target in the same array
//   T&<u32 in pool>                    pool-relative: offset from the base of the GLOBAL array `pool`
//   T&<u32>?                           optional; offset 0 means null
//   self                               in a literal: a link to the value being built
// =====================================================================

// ---------------------------------------------------------------
// Self-relative, optional links: a binary search tree living in ONE array.
// Each node is 12 bytes: an i32 key + two 4-byte links (null included).
// ---------------------------------------------------------------
struct Node { key: i32, left: Node&<u32>?, right: Node&<u32>? }   // omitted optional fields default to null

fn insert(pool: Node[>..]&, key: i32) {
    if pool.len == 0 { pool.push(Node { key: key }); return; }    // first node becomes the root
    var cur .= pool[0];                                           // `.=`: a reference, NOT a copy (copying is forbidden, see below)
    loop {
        if key == cur.key { return; }                             // duplicate: ignore
        let next = if key < cur.key { cur.left } else { cur.right };  // loading a relative link gives a Node? (a normal optional)
        if next { cur .= next; continue; }                        // narrowed to Node&: walk down
        // `push` returns a reference to the new element; `.=` stores it as an offset.
        // Allowed because cur and the new element derive from the SAME root array (pool).
        if key < cur.key { cur.left .= pool.push(Node { key: key }); }
        else             { cur.right .= pool.push(Node { key: key }); }
        return;
    }
}

// Recursive in-order walk (recursive functions need the `recursive` qualifier).
recursive fn in_order(n: Node&, out: i32[>..]&) {
    let l = n.left;                    // a Node? read out of the relative field
    if l { in_order(l, out); }         // narrowed by if
    out.push(n.key);
    let r = n.right;
    if r { in_order(r, out); }
}

// ---------------------------------------------------------------
// The other offset widths: u8, u16, u64, varint.
// Narrower offsets save space but limit how far the target may be.
// ---------------------------------------------------------------
struct Tiny  { v: i64, next: Tiny&<u8>? }      // 1-byte offset (target must be close)
struct Mid   { v: i64, next: Mid&<u16>? }      // 2-byte offset
struct Wide  { v: i64, next: Wide&<u64>? }     // 8-byte offset (any distance)
struct Vari  { v: i64, next: Vari&<varint>? }  // variable-length encoded offset

// ---------------------------------------------------------------
// Pool-relative links + `self`: a circular doubly-linked list.
// `ring` is a GLOBAL reusable pool; the links are offsets from its base.
// The links are NON-optional, so the first node can only be built with `self`
// (there is nothing else to point at yet).
// ---------------------------------------------------------------
struct Ring { val: i64, prev: Ring&<u32 in ring>, next: Ring&<u32 in ring> }
reusable var ring: Ring[>..] = [];

// Insert v after p: the same four stores every time, no null checks.
fn insert_after(p: Ring&, v: i64) -> Ring& {
    let n .= ring.alloc_ref(Ring { val: v, prev: p, next: p.next });  // build in place in the pool
    n.next.prev .= n;                  // rebind links with .=
    p.next .= n;
    return n;
}

// An enum with a self-relative link, to show `&` binders in match.
// It must be used in VARIABLE mode (`Item..`): a fixed-mode enum binds payloads
// only by value, which would copy (and break) the self-relative link.
enum Item { Leaf { v: i64 }, Link { v: i64, to: Item..&<u32>? } }

fn describe(it: Item..&) {
    match it {
        Leaf &l => print("leaf ", l.v),                    // `&l` binds the payload by reference
        Link &k => {                                       // a by-value binder (`Link k`) would be a forbidden copy
            let to = k.to;                                 // Item..? read out of the relative link
            if to { print("link ", k.v, " -> ", if to .== it { "itself" } else { "another item" }); }
        },
    }
}

fn main() {
    // ---------------------------------------------------------------
    // Self-relative tree
    // ---------------------------------------------------------------
    var pool: Node[>..] = [];
    for k in [50, 30, 70, 20, 40, 60, 80] { insert(pool, k as i32); }
    var keys: i32[>..] = [];
    in_order(pool[0], keys);
    print("tree in order: ", keys);
    print("nodes: ", pool.len, ", bytes: ", bytes_of(pool).len, " (12 bytes per node, links included)");

    // ---------------------------------------------------------------
    // A value holding self-relative links CANNOT BE COPIED.
    // Build it in place, bind it with `.=`, and use `&` binders in match.
    // ---------------------------------------------------------------
    // let root = pool[0];             // ERROR: Node holds self-relative links, so this copy is forbidden
    let root .= pool[0];               // OK: bind by reference
    print("root key via .= binding: ", root.key);

    // ---------------------------------------------------------------
    // Other widths: each list is built in place inside its own array.
    // ---------------------------------------------------------------
    var tiny: Tiny[>..] = [Tiny { v: 1 }];
    tiny.push(Tiny { v: 2, next: tiny[0] });   // the literal is pushed INTO tiny, so the link can be stored
    var mid: Mid[>..] = [Mid { v: 10 }];
    mid.push(Mid { v: 20, next: mid[0] });
    var wide: Wide[>..] = [Wide { v: 100 }];
    wide.push(Wide { v: 200, next: wide[0] });
    // A varint link makes Vari VARIABLE-SIZE, so `vari` cannot be indexed (only iterated):
    // keep the references that push returns instead of writing vari[0].
    var vari: Vari[>..] = [];
    let v0 .= vari.push(Vari { v: 1000 });
    let v1 .= vari.push(Vari { v: 2000, next: v0 });
    let t = tiny[1].next;  if t { print("u8 link -> ", t.v); }       // follow each link (narrow first)
    let m = mid[1].next;   if m { print("u16 link -> ", m.v); }
    let w = wide[1].next;  if w { print("u64 link -> ", w.v); }
    let vv = v1.next; if vv { print("varint link -> ", vv.v); }
    print("optional relative link: tiny[0].next == null: ", tiny[0].next == null);  // offset 0 = null
    print("Tiny array bytes (2 x (8 + 1): packed, no padding): ", bytes_of(tiny).len);

    // ---------------------------------------------------------------
    // Pool-relative ring built with `self`
    // ---------------------------------------------------------------
    let head .= ring.push(Ring { val: 0, prev: self, next: self });  // sentinel links to itself
    print("sentinel: next is itself? ", head.next .== head);
    insert_after(head, 1);
    insert_after(head.prev, 2);        // append at the end (before the sentinel)
    insert_after(head.prev, 3);
    var line: u8[>..] = [];
    var n .= head.next;
    while n .!= head { format(line, n.val, " "); n .= n.next; }      // walk until back at the sentinel
    print("ring: ", line, "| slots: ", ring.len);
    // A value whose links are ALL `in pool` copies like any other value:
    let copied = ring[1];              // fine: pool-relative offsets don't depend on where the copy sits
    print("copied pool-linked node val: ", copied.val, ", its next val: ", copied.next.val);

    // ---------------------------------------------------------------
    // `&` binders in match: required for values with self-relative links
    // ---------------------------------------------------------------
    var items: Item..[>..] = [];                       // a sequential array of variable-mode items
    let i0 .= items.push(Item.Leaf { v: 5 });          // push returns a reference to the built element
    let i1 .= items.push(Item.Link { v: 6, to: i0 });  // link stored as an offset within `items`
    describe(i0);
    describe(i1);
}
