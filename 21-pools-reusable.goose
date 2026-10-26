import std;

// ===================================================================
// 21. Pools: reusable and reusable[]
// ===================================================================
// A POOL is a grow-only array (`T[>..]`) with a hidden FREELIST. It is
// for data whose lifetimes don't nest (cache entries, graph nodes that
// get edited, ...): you can free slots in any order and reuse them,
// without a general-purpose allocator.
//
//   reusable var p: T[>..]   — single-slot pool: alloc_index, alloc_ref, free
//   reusable[] var p: T[>..] — slice pool: alloc_slice, realloc_slice, free_slice
//
// A pool may be a local or a global. It NEVER shrinks.

struct Job { n: i32 }

// A global pool works the same way as a local one.
reusable var global_jobs: Job[>..] = [];

// A `T[>..]&` parameter bound to a pool is a "pool reference": it carries
// the freelist too, so pool operations work through it.
fn add_job(pool: Job[>..]&, n: i32) -> i64 { pool.alloc_index(Job { n }) }

fn main() {
    // ---------------------------------------------------------------
    // reusable: single slots
    // ---------------------------------------------------------------
    reusable var pool: Job[>..] = [];          // `reusable` before `var` makes it a pool

    let i0 = pool.alloc_index(Job { 1 });       // index of a slot; pushes since freelist is empty
    let i1 = pool.alloc_index(Job { 5 });       // next slot: index 1
    print("i0 = ", i0, ", i1 = ", i1, ", len = ", pool.len);

    pool.free(i0);                              // put slot 0 back on the freelist
    let i2 = pool.alloc_index(Job { 9 });       // REUSES the freed slot 0
    print("after free(i0): i2 = ", i2, " (slot reused), len = ", pool.len);

    let jr .= pool.alloc_ref(Job { 2 });        // same, but get a REFERENCE to the slot (bind with .=)
    jr.n += 100;                                // write through the reference
    print("alloc_ref slot value = ", jr.n, ", len = ", pool.len);
    let ji = pool.index_of(jr);                 // reference -> index
    print("index_of(jr) = ", ji);
    pool.free(ji);                              // reference -> index -> free
    // pool.free(99);  // would ABORT: free checks that the index is in range

    // free() never releases memory: the array is still 3 long.
    print("len after free = ", pool.len, " (pools never shrink)");

    // A stale reference/index still reads a VALID value of the right type.
    // Slot `ji` was freed; it still holds its old value until reused...
    print("stale read of freed slot: ", pool[ji].n);
    let i3 = pool.alloc_index(Job { 7 });       // ...the next alloc reuses it
    print("after reuse, the same slot holds: ", pool[ji].n, " (i3 = ", i3, ")");
    // This is a LOGIC bug (like a stale index), never memory corruption.

    // push/append bypass the freelist and always add at the end.
    pool.free(i1);                              // slot 1 is free now...
    pool.push(Job { 42 });                      // ...but push still appends at index 3
    print("push ignores the freelist: len = ", pool.len, ", pool[3].n = ", pool[3].n);

    // Pool reference parameter + a global pool.
    let g0 = add_job(global_jobs, 11);
    let g1 = add_job(global_jobs, 12);
    global_jobs.free(g0);
    let g2 = add_job(global_jobs, 13);          // reuses g0's slot through the parameter
    print("global pool: g0 = ", g0, ", g1 = ", g1, ", g2 = ", g2, ", len = ", global_jobs.len);

    // ---------------------------------------------------------------
    // reusable[]: slice pools (runs of elements)
    // ---------------------------------------------------------------
    // Hands out contiguous RUNS. Its freelist holds spans and merges neighbours.
    reusable[] var spans: i64[>..] = [];

    let s1 = spans.alloc_slice(3);              // 3 default-valued (0) elements
    s1[0] = 1; s1[1] = 2; s1[2] = 3;            // a plain slice: index and write it
    print("s1 = ", s1, ", spans = ", spans);

    let s2 = spans.realloc_slice(s1, 5);        // resize to 5: s1 ends the array, so it grows IN PLACE
    print("s2 = ", s2, " (grown in place, new elements are 0)");

    let s3 = spans.alloc_slice(2);              // another run after s2
    s3[0] = 7; s3[1] = 8;
    spans.free_slice(s2);                       // give s2's 5 elements back
    let s4 = spans.alloc_slice(2);              // taken from the freed span, RESET to defaults
    print("s4 = ", s4, " (reused from freed span), s3 = ", s3);
    print("spans len = ", spans.len, ", spans = ", spans);
    spans.free_slice(s4);                       // free the run we just got
    spans.free_slice(s3);

    // Rules (compile errors):
    //   spans.alloc_index(1);   // ERROR: a slice pool has no single-slot operations
    //   pool.alloc_slice(2);    // ERROR: a plain `reusable` pool has no slice operations
    // free_slice/realloc_slice must get one of the pool's own runs; if the
    // compiler can't prove that, it checks at run time and aborts if not.
    print("done");
}
